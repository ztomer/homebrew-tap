#!/usr/bin/env bash
# The one enumeration of the tap's package files, sourced by every tool that lists them
# (tap_consistency.sh, brew_style.sh). Expects $HERE to be the tap root.
#
# WHY ONE PLACE (D.TAPDIRT, second half). Each tool used to list Formula/ and Casks/
# with its own `find` or glob, so a file git does not track -- which never ships,
# nothing pushes it -- was judged by every one of them as if it did. The first fix
# named such a file in `untracked_problems` but left three enumerations on disk,
# so a stray still entered README parity and the style run. A tool that lists
# packages goes through here, or it is the next place a stray is judged.

# True when $HERE is the root of its OWN git checkout. `--is-inside-work-tree` is
# not that: a fixture directory nested in some other repo (a scratch dir under a
# repo, a tap vendored in a monorepo) answers true for the PARENT, and every file
# in it then reads as untracked there.
in_own_checkout() {
    local prefix
    prefix="$(git -C "$HERE" rev-parse --show-prefix 2>/dev/null)" || return 1
    [ -z "$prefix" ]
}

# Print the absolute path of every package file (Formula/**.rb, Casks/**.rb), sorted:
# the TRACKED ones when $HERE is a checkout, whatever is on disk when it is not
# (a test fixture has no index to ask). A tracked file deleted from the working
# tree is skipped, not listed: there is nothing to read.
package_files() {
    local f
    if in_own_checkout; then
        while IFS= read -r f; do
            [ -f "$HERE/$f" ] && printf '%s\n' "$HERE/$f"
        done < <(git -C "$HERE" ls-files -- 'Formula/*.rb' 'Casks/*.rb' | sort)
    else
        find "$HERE/Formula" "$HERE/Casks" -name '*.rb' 2>/dev/null | sort
    fi
}
