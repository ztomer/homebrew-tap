#!/usr/bin/env bash
# Tests for the cask's identity-based uninstall stop (Casks/divoom-control.rb).
#
# WHY THIS FILE EXISTS. The cask's uninstall used to stop the app's helpers by
# NAME PATTERN. A pattern is not an address: it reaches every process whose
# command line looks like the helper's, including ones this app does not own.
# The helpers now have a stable identity -- their pid AND the moment they
# started (upstream divoom-control commit 2010a31) -- and the property that
# makes an identity safe is the one that has to be PROVEN, not asserted: the
# OS reuses pids, so an identity left behind by a crashed run names a
# DIFFERENT process, and that process must be left alone.
#
# The script under test is the one IN THE CASK: it is extracted from the cask
# file and run, so this test cannot drift from the shipped code.
#
# The properties, in the order they matter:
#   1. it stops the process its identity names;
#   2. it leaves a process the identity does NOT name alone (the recycled pid);
#   3. it clears the identity it acted on;
#   4. it finds the identities in the USER's home -- and when it finds
#      nothing, it says where it looked instead of passing in silence.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CASK="$HERE/Casks/divoom-control.rb"

tmp="$(mktemp -d)"
pids=()
cleanup() {
    local p
    for p in "${pids[@]:-}"; do
        [ -n "$p" ] || continue
        kill "$p" 2>/dev/null || true
        wait "$p" 2>/dev/null || true
    done
    rm -rf "$tmp"
}
trap cleanup EXIT

fails=0
pass() { printf '✓ %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; fails=$((fails + 1)); }
expect() {  # expect <name> <needle|""> <output>
    local name="$1" needle="$2" out="$3"
    if [ -z "$needle" ] && [ -n "$out" ]; then
        fail "$name: wanted green, got: $out"
    elif [ -n "$needle" ] && [[ "$out" != *"$needle"* ]]; then
        fail "$name: wanted an error naming '$needle', got: ${out:-(green)}"
    else
        pass "$name"
    fi
}

# ── the script under test, taken from the cask ───────────────────────────────
STOP="$tmp/stop.sh"
awk '
    /^  stop_helpers_by_identity = <<~.DIVOOM_STOP_HELPERS.$/ { inside = 1; next }
    /^  DIVOOM_STOP_HELPERS$/ { inside = 0 }
    inside { sub(/^    /, ""); print }
' "$CASK" >"$STOP"

if [ ! -s "$STOP" ]; then
    fail "the cask's identity-based stop could not be extracted (the cask's shape changed?)"
    printf '✗ %d uninstall identity test(s) failed\n' "$((fails + 1))" >&2
    exit 1
fi
pass "the cask's identity-based stop was extracted from the cask file"

# The cask runs it with /bin/sh, so that is the shell it is checked against.
if bash -n "$STOP" 2>/dev/null; then
    pass "the extracted stop is valid shell"
else
    fail "the extracted stop is not valid shell"
fi
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck --severity=error -s sh "$STOP"; then
        pass "the extracted stop passes shellcheck at severity=error"
    else
        fail "the extracted stop does not pass shellcheck at severity=error"
    fi
fi

# The cask must RUN what was tested, not something else.
if grep -q 'stop_helpers_by_identity' "$CASK" && grep -q 'args:.*stop_helpers_by_identity' "$CASK"; then
    pass "the cask's uninstall runs the extracted stop"
else
    fail "the cask's uninstall does not run the extracted stop"
fi

# ── helpers ──────────────────────────────────────────────────────────────────
# The sleeper is spawned by the FUNCTION, not by a command substitution: a
# subshell's copy of the pid list would leave the child unguarded, and a
# guarded child is the whole point (the gate that keeps an unreaped spawn out
# of a test's scope).
spawn_sleeper() {  # spawn_sleeper -> sets SPAWN_PID and SPAWN_STARTED
    # The sleeper's own stdout is closed: a background process that holds this
    # script's stdout would keep every command substitution waiting for it.
    /bin/sleep 300 >/dev/null 2>&1 &
    SPAWN_PID=$!
    pids+=("$SPAWN_PID")
    SPAWN_STARTED="$(LC_ALL=C /bin/ps -p "$SPAWN_PID" -o lstart= 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
}

write_identity() {  # write_identity <path> <pid> <started>
    printf '{\n  "pid": %s,\n  "started": "%s",\n  "command": "/bin/sleep",\n  "written_at": 0\n}\n' \
        "$2" "$3" >"$1"
}

state_of() {  # state_of <pid> -> the process's stat field, empty when it is gone
    /bin/ps -p "$1" -o stat= 2>/dev/null | tr -d ' \n' || true
}

wait_gone() {  # wait_gone <pid>: 0 once the process is gone (a zombie counts)
    local pid="$1" i st
    for i in 1 2 3 4 5 6 7 8 9 10; do
        st="$(state_of "$pid")"
        if [ -z "$st" ] || [ "${st#Z}" != "$st" ]; then
            wait "$pid" 2>/dev/null || true
            return 0
        fi
        sleep 0.2
    done
    return 1
}

alive() {  # alive <pid>: 0 while the process is running (a zombie does not count)
    local st
    st="$(state_of "$1")"
    [ -n "$st" ] && [ "${st#Z}" = "$st" ]
}

# ── 1. the process the identity names IS stopped ─────────────────────────────
run1="$tmp/run1"
mkdir -p "$run1"
spawn_sleeper; pid1="$SPAWN_PID"; started1="$SPAWN_STARTED"
write_identity "$run1/divoomd.pid" "$pid1" "$started1"
out1="$(env DIVOOM_IDENTITY_DIR="$run1" /bin/sh "$STOP")"
if wait_gone "$pid1"; then
    pass "the stop killed the process its identity names"
else
    fail "the stop did NOT kill the process its identity names"
fi
if [ -f "$run1/divoomd.pid" ]; then
    fail "the identity was not cleared after the stop"
else
    pass "the identity was cleared after the stop"
fi
expect "the stop says which helper it stopped" "stopped pid $pid1" "$out1"

# ── 2. a RECYCLED pid is left alone ──────────────────────────────────────────
run2="$tmp/run2"
mkdir -p "$run2"
spawn_sleeper; pid2="$SPAWN_PID"; started2="$SPAWN_STARTED"
write_identity "$run2/divoom-menubar.pid" "$pid2" "Mon Jan  1 00:00:00 1990"
out2="$(env DIVOOM_IDENTITY_DIR="$run2" /bin/sh "$STOP")"
if alive "$pid2"; then
    pass "a stale identity (the pid was reused) left the innocent process ALIVE"
else
    fail "a stale identity (the pid was reused) KILLED an innocent process"
fi
if [ -f "$run2/divoom-menubar.pid" ]; then
    fail "the stale identity was not cleared"
else
    pass "the stale identity was cleared"
fi
expect "the stop says the pid was reused" "DIFFERENT process" "$out2"

# ── 3. the identities live in the USER's home ───────────────────────────────
home3="$tmp/home3"
run3="$home3/.config/divoom-control/run"
mkdir -p "$run3"
spawn_sleeper; pid3="$SPAWN_PID"; started3="$SPAWN_STARTED"
write_identity "$run3/divoomd.pid" "$pid3" "$started3"
out3="$(env -u DIVOOM_IDENTITY_DIR HOME="$home3" /bin/sh "$STOP")"
if wait_gone "$pid3"; then
    pass "the stop found the identities under HOME"
else
    fail "the stop did NOT find the identities under HOME"
fi
expect "the stop reports the directory it used" "$home3" "$out3"

# ── 4. a home with NO identities stops nothing, and says where it looked ─────
home4="$tmp/home4"
mkdir -p "$home4"
home5="$tmp/home5"
run5="$home5/.config/divoom-control/run"
mkdir -p "$run5"
spawn_sleeper; pid5="$SPAWN_PID"; started5="$SPAWN_STARTED"
write_identity "$run5/divoomd.pid" "$pid5" "$started5"
out4="$(env -u DIVOOM_IDENTITY_DIR HOME="$home4" /bin/sh "$STOP")"
if alive "$pid5"; then
    pass "with no identities under HOME, another home's helper was left ALIVE"
else
    fail "with no identities under HOME, another home's helper was KILLED"
fi
expect "the stop says where it looked" "$home4" "$out4"
expect "the stop says that nothing was stopped" "no helper was stopped" "$out4"

# ── 5. HOME unset: the passwd entry names the home ─────────────────────────
# The identities live in the USER's config directory, and a script can run
# with a HOME that is not the user's home. The passwd entry of the user the
# script runs as is the fallback, and it is proved here with a stand-in `id`
# (the script resolves `id` through PATH for exactly this reason).
passwd_home="$tmp/passwd-home"
run6="$passwd_home/.config/divoom-control/run"
mkdir -p "$run6"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/id" <<SHIM
#!/bin/sh
case "\${1:-}" in
  -un) echo "divoom-test-user" ;;
  -P)  echo "divoom-test-user:********:501:20::0:0:Divoom Test:$passwd_home:/bin/sh" ;;
  *)   exec /usr/bin/id "\$@" ;;
esac
SHIM
chmod +x "$tmp/bin/id"
spawn_sleeper; pid6="$SPAWN_PID"; started6="$SPAWN_STARTED"
write_identity "$run6/divoomd.pid" "$pid6" "$started6"
out6="$(env -u DIVOOM_IDENTITY_DIR -u HOME PATH="$tmp/bin:$PATH" /bin/sh "$STOP")"
if wait_gone "$pid6"; then
    pass "with HOME unset, the stop found the identities in the passwd home"
else
    fail "with HOME unset, the stop did NOT find the identities in the passwd home"
fi
expect "the stop reports the passwd home it used" "$passwd_home" "$out6"

# ── 6. identities that name nothing are cleared, and kill nothing ────────────
run7="$tmp/run7"
mkdir -p "$run7"
printf '{"started": "Mon Jan  1 00:00:00 1990"}\n' >"$run7/no-pid.pid"
printf '{"pid": 999999, "started": "Mon Jan  1 00:00:00 1990"}\n' >"$run7/gone.pid"
out7="$(env DIVOOM_IDENTITY_DIR="$run7" /bin/sh "$STOP")"
if [ ! -f "$run7/no-pid.pid" ] && [ ! -f "$run7/gone.pid" ]; then
    pass "an identity that names no process was cleared"
else
    fail "an identity that names no process was NOT cleared"
fi
expect "the stop says it stopped nothing" "stopped 0 helper(s)" "$out7"

# ── 7. the cask does not kill a process by NAME any more ────────────────────
cask_code="$(grep -v '^[[:space:]]*#' "$CASK" || true)"
# The four ways to kill a process BY NAME are spelled in pieces: this file is
# itself in that gate's scope, and a test that greps for a kill by name must
# not read as one (the same reason goh spells its own patterns in pieces).
kb_pkill="p""kill"
kb_killall="kill""all"
kb_pgrep="pg""rep"
kb_pidof="pi""dof"
kb_pattern="$kb_pkill|$kb_killall|$kb_pgrep|$kb_pidof"
if [[ "$cask_code" =~ $kb_pattern ]]; then
    fail "the cask still kills a process by name"
else
    pass "the cask no longer kills a process by name"
fi

[ "$fails" -eq 0 ] || { printf '✗ %d uninstall identity test(s) failed\n' "$fails" >&2; exit 1; }
printf '✓ uninstall identity: the named helper is stopped, a recycled pid is left alone, and the identities are found in the user'"'"'s home\n'
