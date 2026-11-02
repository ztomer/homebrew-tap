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


# EVERY run of the stop goes through here. The stop also sweeps the installed
# app's own executables (and the holder of the tray's lock), so an unsandboxed
# run on a machine with Divoom installed would stop the developer's REAL tray
# and daemon. Pointing it at a directory that holds no app makes a test run
# unable to reach anything it did not spawn.
run_stop() {  # run_stop [env args...]
    env "$@" /bin/sh "$STOP" "$tmp/no-apps-here"
}

# ── 1. the process the identity names IS stopped ─────────────────────────────
run1="$tmp/run1"
mkdir -p "$run1"
spawn_sleeper; pid1="$SPAWN_PID"; started1="$SPAWN_STARTED"
write_identity "$run1/divoomd.pid" "$pid1" "$started1"
out1="$(run_stop DIVOOM_IDENTITY_DIR="$run1")"
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
out2="$(run_stop DIVOOM_IDENTITY_DIR="$run2")"
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
out3="$(run_stop -u DIVOOM_IDENTITY_DIR HOME="$home3")"
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
out4="$(run_stop -u DIVOOM_IDENTITY_DIR HOME="$home4")"
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
out6="$(run_stop -u DIVOOM_IDENTITY_DIR -u HOME PATH="$tmp/bin:$PATH")"
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
out7="$(run_stop DIVOOM_IDENTITY_DIR="$run7")"
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

# ── 8. NO process the app can start survives, identity or not ────────────────
# Since D.HELPER the app starts its helpers as helper apps under
# Contents/Helpers (`open -n -g`). The menu-bar agent writes no identity file,
# so the identity pass cannot see it, and a tray the user kept past the GUI
# survived an uninstall (ROADMAP P1.19). Nor does the MCP server the GUI
# starts (`divoomd mcp`). Two addresses reach them without a name pattern: the
# executable's PATH inside the app being removed (a process running a binary
# out of that bundle must die before the bundle goes), and the HOLDER of the
# tray's single-instance lock, wherever the app was installed.
sandbox_app="$tmp/Applications/Divoom.app/Contents"
agent_exe="$sandbox_app/Helpers/Divoom Menubar.app/Contents/MacOS/divoom-menubar"
daemon_exe="$sandbox_app/Helpers/divoomd.app/Contents/MacOS/divoomd"
mkdir -p "$(dirname "$agent_exe")" "$(dirname "$daemon_exe")" "$tmp/elsewhere"
for exe in "$agent_exe" "$daemon_exe" "$tmp/elsewhere/divoom-menubar"; do
    # A copy of a system binary must be re-signed to run on Apple silicon.
    cp /bin/sleep "$exe"
    codesign -f -s - "$exe" >/dev/null 2>&1
done
run8="$tmp/run8"
mkdir -p "$run8"
: >"$run8/divoom-menubar.lock"

spawn_exe() {  # spawn_exe <exe> [stdin-file] -> SPAWN_PID (no identity is written)
    "$1" 300 <"${2:-/dev/null}" >/dev/null 2>&1 &
    SPAWN_PID=$!
    pids+=("$SPAWN_PID")
}
spawn_exe "$agent_exe";  pid_agent="$SPAWN_PID"
spawn_exe "$daemon_exe"; pid_mcp="$SPAWN_PID"
# A tray from an app installed somewhere else: only the lock it holds names it.
spawn_exe "$tmp/elsewhere/divoom-menubar" "$run8/divoom-menubar.lock"; pid_lock="$SPAWN_PID"
# A process that merely LOOKS like a helper, holding nothing of the app's.
decoy_exe="$tmp/decoy/Divoom.app/Contents/MacOS/divoom-menubar"
mkdir -p "$(dirname "$decoy_exe")"
cp /bin/sleep "$decoy_exe"
codesign -f -s - "$decoy_exe" >/dev/null 2>&1
spawn_exe "$decoy_exe"; pid_decoy="$SPAWN_PID"
sleep 0.3

out8="$(env DIVOOM_IDENTITY_DIR="$run8" /bin/sh "$STOP" "$tmp/Applications")"
if wait_gone "$pid_agent"; then
    pass "the menu-bar helper app (no identity file) did not survive the uninstall"
else
    fail "the menu-bar helper app (no identity file) SURVIVED the uninstall"
fi
if wait_gone "$pid_mcp"; then
    pass "another process running out of the app's bundle did not survive"
else
    fail "another process running out of the app's bundle SURVIVED"
fi
if wait_gone "$pid_lock"; then
    pass "the holder of the tray's lock did not survive, wherever its app lived"
else
    fail "the holder of the tray's lock SURVIVED"
fi
if alive "$pid_decoy"; then
    pass "a process named like the app but not running out of it was left ALIVE"
else
    fail "a process named like the app but not running out of it was KILLED"
fi
expect "the stop says it stopped helpers by the address they hold" "by the address they hold" "$out8"

# ── 9. the sweep finds the bundle wherever brew installed it ─────────────────
# `brew install --cask --appdir=DIR` puts Divoom.app in DIR, and Homebrew keeps
# that choice in the cask's own config. The sweep used to read $DIVOOM_APP_DIR
# and otherwise assume /Applications, so a cask installed elsewhere left every
# process running out of its bundle alive (queue D.UNINSTDIR; only the tray was
# caught, by its lock). The appdir now reaches the script as an ARGUMENT the
# cask fills from its own `appdir`, which Homebrew resolves per installation.
# This section asks Homebrew itself what it would run for a given appdir
# (`brew ruby` loads the cask with that config) and runs exactly that. The
# environment variable stays set to a DECOY: it must not outrank the cask, and
# a run that fell back to the real /Applications would reach a developer's
# real tray and daemon -- so the decoy also keeps the pre-fix script off them.
loader="$tmp/load_uninstall.rb"
cat >"$loader" <<'RUBY'
appdir, script_out, args_out = ARGV
cask = Cask::CaskLoader.load("ztomer/tap/divoom-control")
cask.config = Cask::Config.new(explicit: { appdir: appdir }) unless appdir.empty?
directives = cask.artifacts.grep(Cask::Artifact::Uninstall).first.directives
script = directives.fetch(:script)
File.write(script_out, script.fetch(:args)[1])
File.write(args_out, script.fetch(:args)[2..].join("\n") + "\n")
puts script.fetch(:executable)
RUBY

run_brew_script() {  # run_brew_script <appdir|""> <identity-dir> -> stdout of the uninstall script
    local appdir="$1" idir="$2" exe
    local script="$tmp/brew_script.sh" argfile="$tmp/brew_args.txt"
    exe="$(HOMEBREW_NO_AUTO_UPDATE=1 brew ruby "$loader" "$appdir" "$script" "$argfile")"
    local args=()
    while IFS= read -r line; do args+=("$line"); done <"$argfile"
    env DIVOOM_APP_DIR="$tmp/no-apps-here" DIVOOM_IDENTITY_DIR="$idir" \
        "$exe" -c "$(cat "$script")" "${args[@]}"
}

if command -v brew >/dev/null 2>&1; then
    run9="$tmp/run9"
    mkdir -p "$run9"
    odd_apps="$tmp/Odd Apps Dir"
    odd_exe="$odd_apps/Divoom.app/Contents/Helpers/divoomd.app/Contents/MacOS/divoomd"
    mkdir -p "$(dirname "$odd_exe")"
    cp /bin/sleep "$odd_exe"
    codesign -f -s - "$odd_exe" >/dev/null 2>&1
    spawn_exe "$odd_exe"; pid_odd="$SPAWN_PID"
    sleep 0.3
    out9="$(run_brew_script "$odd_apps" "$run9")"
    if wait_gone "$pid_odd"; then
        pass "a bundle in a non-default appdir (--appdir) did not survive the uninstall"
    else
        fail "a bundle in a non-default appdir (--appdir) SURVIVED the uninstall"
    fi
    expect "the stop says it stopped helpers by the address they hold" "by the address they hold" "$out9"

    # Without --appdir Homebrew's default applies, and the script sweeps it. A
    # fake process under the REAL /Applications is never spawned here; the
    # directory the script decided to sweep is read off the arguments instead.
    HOMEBREW_NO_AUTO_UPDATE=1 brew ruby "$loader" "" "$tmp/brew_script_default.sh" "$tmp/brew_args_default.txt" >/dev/null
    if [ "$(sed -n 2p "$tmp/brew_args_default.txt")" = "/Applications" ]; then
        pass "with no --appdir the cask hands the script Homebrew's default appdir"
    else
        fail "with no --appdir the cask hands the script: $(sed -n 2p "$tmp/brew_args_default.txt")"
    fi
else
    printf '⚠ brew is not installed: the appdir channel (section 9) was not checked\n' >&2
fi

[ "$fails" -eq 0 ] || { printf '✗ %d uninstall identity test(s) failed\n' "$fails" >&2; exit 1; }
printf '✓ uninstall identity: the named helper is stopped, a recycled pid is left alone, and the identities are found in the user'"'"'s home\n'
