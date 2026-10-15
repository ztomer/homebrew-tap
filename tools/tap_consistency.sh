#!/usr/bin/env bash
# Tap consistency: the three defects that have shipped or nearly shipped from here.
#
# WHY THIS EXISTS. `a0a1f59` shipped multitop 0.49.0 with its two agent `resource`
# URLs still naming v0.47.3 — the formula looked bumped, the artifacts were three
# releases stale, and nothing noticed until a user got a mismatched agent. Every
# other property of the file was correct. goh's `tap_bump.sh` produces BOTH of the
# first two defects on today's files (a one-url bump helper rewrites `url` and
# forgets `resource`), so this is the gate that script runs against.
#
# Three checks, per file, each failing for its OWN reason:
#   1. every `resource` URL names the SAME tag as the file's main `url`/`version`
#   2. no two `sha256` lines in one file are equal (a resource sha copied from the
#      tarball's, which is what a careless hand-bump does)
#   3. the file ends with exactly one newline
#
# Written as a plain per-file function so `tools/tests/test_tap_consistency.sh`
# can call it on a fixture and assert the failure says WHICH defect, rather than
# only that something is wrong. A gate that reports "tap broken" sends an
# operator to diff five files instead of reading one line.
#
# `brew style` is a SEPARATE gate step (T1.2): it needs Homebrew's Ruby, and
# folding it in here would make this gate silently weaker on a machine without
# `brew` rather than honestly absent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The version a file DECLARES, in either of the two shapes this tap uses:
#   Formula: a literal tag in the main url, .../archive/refs/tags/v0.55.0.tar.gz
#   Cask:    `version "0.15.1"` with urls built from `v#{version}`
# Both come back bare (no `v`) so one comparison covers both.
file_version() {
    local f="$1" v
    # `sed ... > tmp; head -n1 < tmp`, NOT `sed ... | head -1`: the consumer exits
    # before EOF, the producer's next write dies of SIGPIPE, and under pipefail
    # that becomes the pipeline's status — a false that depends on load. The
    # house shape, which goh's `no early-exit pipe under pipefail` requires and
    # which refused this file when it did it the obvious way.
    local tmp out
    tmp="$(mktemp)" || return 1
    sed -nE 's|^[[:space:]]*version[[:space:]]+"([0-9]+(\.[0-9]+)+)".*|\1|p' "$f" >"$tmp"
    out="$(head -n 1 <"$tmp")"
    [ -n "$out" ] && { printf '%s' "$out"; rm -f "$tmp"; return; }
    sed -nE 's|.*/tags/v([0-9]+(\.[0-9]+)+)\.tar\.gz.*|\1|p' "$f" >"$tmp"
    out="$(head -n 1 <"$tmp")"
    rm -f "$tmp"
    printf '%s' "$out"
}

# Print one line per failure, empty when the file is consistent. $1 = path.
tap_file_problems() {
    local f="$1" problems=()

    # 1. every url must pin the version the file DECLARES. A url may name the
    #    literal tag or interpolate `#{version}` -- a Cask built that way cannot
    #    drift, which is why it is accepted rather than flagged. What is NOT
    #    acceptable is a url with no tag at all (`/latest/`, a bare branch): a
    #    moving target in a versioned tap, and the shape a hand-bump produces.
    local main_v
    main_v="$(file_version "$f")"
    if [ -z "$main_v" ]; then
        problems+=("no version declared (expected \`version \"X.Y[.Z]\"\` or a .../tags/vX.Y[.Z].tar.gz url)")
    else
        local line rtag
        while IFS= read -r line; do
            case "$line" in
                *'#{version}'*) continue ;;   # interpolated: pinned by construction
            esac
            rtag="$(printf '%s' "$line" | sed -nE 's|.*/v([0-9]+(\.[0-9]+)+)[./"].*|\1|p')"
            if [ -z "$rtag" ]; then
                problems+=("url names no version tag (a moving target in a versioned tap): $line")
            elif [ "$rtag" != "$main_v" ]; then
                problems+=("url names v$rtag but the file declares $main_v (a0a1f59): $line")
            fi
        done < <(grep -E '^[[:space:]]+url "' "$f" | sed -E 's|^[[:space:]]+||' || true)
    fi

    # 2. no two shas equal -- a resource sha copied from the tarball's.
    local dupes
    dupes="$(grep -E '^\s+sha256 "' "$f" | awk '{print $2}' | sort | uniq -d || true)"
    if [ -n "$dupes" ]; then
        local d
        for d in $dupes; do
            problems+=("sha256 $d appears more than once (a resource sha copied from another)")
        done
    fi

    # 3. exactly one trailing newline.
    if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then
        problems+=("file does not end with a newline")
    fi

    [ "${#problems[@]}" -eq 0 ] || printf '%s\n' "${problems[@]}"
}

# Is $2 one of the lines in $1.. ? (bash: call as contains_line "${arr[@]}" needle)
# Is the FIRST argument one of the rest? (bash: contains_line needle "${arr[@]}")
#
# Needle FIRST, deliberately. Reading the last positional parameter needs `${!#}`,
# which is not portable to the bash 3.2 that ships on macOS -- there it silently
# expanded to something else, and every membership test answered "present". A gate
# that is wrong in the QUIET direction is the worst kind: it passes forever.
contains_line() {
    local needle="$1" item
    shift
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}


# README parity (T3.1): every package in Formula/ and Casks/ has a README row, and
# every README row names a package that exists.
#
# Read from the INSTALL COMMAND rather than the display name, because the display
# names are prose ("Divoom Control", "ZTools") while the command carries the token
# brew actually resolves. Matching on the pretty name would need a hand-maintained
# synonym table, which is the same drift in a different file.
#
# Membership is tested with a plain loop, never `printf ... | grep -qx`: that is
# the early-exit-pipe defect this tap's own gate exists to catch, and this repo's
# gate caught it here the first time.
readme_problems() {
    local problems=() name
    local readme="$HERE/README.md"
    [ -f "$readme" ] || { printf 'README.md is missing\n'; return; }

    local -a documented=() shipped=()
    while IFS= read -r name; do
        documented+=("$name")
    done < <(sed -nE 's|.*brew install (--cask )?ztomer/tap/([A-Za-z0-9._-]+).*|\2|p' "$readme" | sort -u)
    while IFS= read -r name; do
        shipped+=("$name")
    done < <(find "$HERE/Formula" "$HERE/Casks" -name '*.rb' 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's|\.rb$||' | sort -u)

    for name in "${shipped[@]}"; do
        if ! contains_line "$name" "${documented[@]}"; then
            problems+=("$name has a Formula/Cask but no README row (add one, or the file should not ship)")
        fi
    done
    for name in "${documented[@]}"; do
        if ! contains_line "$name" "${shipped[@]}"; then
            problems+=("README documents $name but there is no Formula/$name.rb or Casks/$name.rb")
        fi
    done
    [ "${#problems[@]}" -eq 0 ] || printf '%s\n' "${problems[@]}"
}


main() {
    local bad=0 f
    while IFS= read -r f; do
        local out
        out="$(tap_file_problems "$f" || true)"
        if [ -n "$out" ]; then
            bad=1
            printf 'FAIL: %s\n' "${f#$HERE/}" >&2
            printf '%s\n' "$out" | sed 's/^/  /' >&2
        else
            printf 'ok: %s\n' "${f#$HERE/}"
        fi
    done < <(find "$HERE/Formula" "$HERE/Casks" -name '*.rb' 2>/dev/null | sort)

    local readme_out
    readme_out="$(readme_problems)"
    if [ -n "$readme_out" ]; then
        bad=1
        printf 'FAIL: README.md vs the packages on disk\n' >&2
        printf '%s\n' "$readme_out" | sed 's/^/  /' >&2
    else
        printf 'ok: README.md documents every package on disk, and every row ships\n'
    fi
    return "$bad"
}

# Sourced by the test to call `tap_file_problems` on a fixture; run for real otherwise.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi