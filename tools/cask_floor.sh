#!/usr/bin/env bash
# A cask's `depends_on macos:` is held to the floor its producer WRITES.
#
# WHY THIS EXISTS. CadGoose's minimum macOS is written once, in its
# cmake/MacOSFloor.cmake, and its own check (tools/check_macos_floor.py) holds the
# built bundle to it. The cask that installs that bundle lives HERE, so the clause
# holding the cask's `depends_on macos:` to the same floor lives here too (CadGoose
# ROADMAP G0.18). It used to be checked against a second copy of the cask inside
# CadGoose, which had drifted: version 0.5.3, a placeholder sha, six `brew style`
# offenses. A check on a copy is a check on nothing.
#
# The floor is read AT THE TAG THE CASK SHIPS (`v<version>`): the cask describes that
# release, not the producer's main. A tag that predates the floor file (CadGoose v1.81
# predates G0.14) reads the default branch instead, and says so. A fetch that fails for
# any other reason is red: a gate that cannot see the floor must not report it held.
#
# Homebrew maps version to codename (26 -> :tahoe), not a table here: a hand table is
# the same drift in a third file. `brew` is already a hard requirement of this gate
# (tools/brew_style.sh).
#
# Sourced by tools/tests/test_cask_floor.sh, which replaces `fetch_producer_file` (the
# network) and `codename_for` with fixtures; run for real otherwise.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"
# shellcheck source=/dev/null
. "$GOH/tui/lib.sh"

# One row per cask whose producer writes a floor: cask, repo, path, cmake variable.
CASK_FLOORS=(
    "cadgoose ztomer/CadGoose cmake/MacOSFloor.cmake CG_MACOS_FLOOR"
)

# Print <path> at <ref> of GitHub repo <repo>. Exit 44 when the file is absent there
# (a 404), 1 on any other failure.
fetch_producer_file() {
    local repo="$1" ref="$2" path="$3" out errf rc=0
    errf="$(mktemp)"
    out="$(gh api -H "Accept: application/vnd.github.raw" \
        "repos/$repo/contents/$path?ref=$ref" </dev/null 2>"$errf")" || rc=$?
    if [ "$rc" -ne 0 ]; then
        if grep -q "HTTP 404" "$errf"; then rm -f "$errf"; return 44; fi
        cat "$errf" >&2; rm -f "$errf"; return 1
    fi
    rm -f "$errf"
    printf '%s\n' "$out"
}

# The floor a cmake file sets: `set(<var> "26.0")` -> 26.0. Non-zero when absent.
floor_from_cmake() {
    local text="$1" var="$2" floor
    floor="$(printf '%s\n' "$text" \
        | sed -nE "s/^[[:space:]]*set\\(${var}[[:space:]]+\"([0-9]+(\\.[0-9]+)*)\"\\).*/\\1/p")"
    [ -n "$floor" ] || return 1
    printf '%s' "${floor%%$'\n'*}"
}

# Homebrew's symbol for a macOS version: 26.0 -> tahoe. Non-zero when it has none.
codename_for() {
    local sym
    sym="$(brew ruby -e 'puts MacOSVersion.new(ARGV[0]).to_sym' "$1" </dev/null 2>/dev/null)" \
        || return 1
    [[ "$sym" =~ ^[a-z_]+$ && "$sym" != dunno ]] || return 1
    printf '%s' "$sym"
}

# Problems with a cask's macOS requirement, given the codename it must name. Exactly
# one `depends_on macos: :<codename>`: a bare symbol is a minimum in Homebrew, and the
# ">= :name" string form is deprecated.
cask_floor_problems() {
    local f="$1" want=":$2" found
    found="$(sed -nE 's/^[[:space:]]*depends_on[[:space:]]+macos:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' "$f")"
    if [ "$found" != "$want" ]; then
        printf 'needs exactly `depends_on macos: %s`, has %s\n' "$want" \
            "$( [ -n "$found" ] && printf '%s' "$found" | tr '\n' ' ' || printf 'none')"
    fi
}

# check_cask <cask> <file> <repo> <path> <var>: one line per problem, empty when held.
check_cask() {
    local name="$1" f="$2" repo="$3" path="$4" var="$5" version text rc=0 ref floor sym
    version="$(sed -nE 's/^[[:space:]]*version[[:space:]]+"([^"]+)".*/\1/p' "$f")"
    [ -n "$version" ] || { printf 'Casks/%s.rb declares no version\n' "$name"; return; }
    ref="v$version"
    text="$(fetch_producer_file "$repo" "$ref" "$path")" || rc=$?
    if [ "$rc" -eq 44 ]; then
        info "$name: $repo $ref predates $path; reading the default branch" >&2
        ref=HEAD rc=0
        text="$(fetch_producer_file "$repo" "$ref" "$path")" || rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        printf 'could not read %s:%s at %s (exit %s): the floor is unchecked, not held\n' \
            "$repo" "$path" "$ref" "$rc"
        return
    fi
    floor="$(floor_from_cmake "$text" "$var")" \
        || { printf '%s:%s at %s sets no %s\n' "$repo" "$path" "$ref" "$var"; return; }
    sym="$(codename_for "$floor")" \
        || { printf 'Homebrew has no codename for macOS %s (%s at %s)\n' "$floor" "$repo" "$ref"; return; }
    local out
    out="$(cask_floor_problems "$f" "$sym")"
    [ -z "$out" ] || printf 'Casks/%s.rb: %s (%s floor is %s at %s)\n' "$name" "$out" "$repo" "$floor" "$ref"
}

main() {
    local bad=0 row name repo path var f out
    for row in "${CASK_FLOORS[@]}"; do
        read -r name repo path var <<<"$row"
        f="$HERE/Casks/$name.rb"
        if [ ! -f "$f" ]; then
            err "Casks/$name.rb is listed in CASK_FLOORS but does not exist"; bad=1; continue
        fi
        out="$(check_cask "$name" "$f" "$repo" "$path" "$var")"
        if [ -n "$out" ]; then
            bad=1
            while IFS= read -r line; do err "$line"; done <<<"$out"
        else
            ok "Casks/$name.rb: depends_on macos matches $repo's $path"
        fi
    done
    return "$bad"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
