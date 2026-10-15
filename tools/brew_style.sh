#!/usr/bin/env bash
# `brew style` over this tap's formula and casks (T1.2).
#
# WHY A WRAPPER. `brew style` needs Homebrew's Ruby and rubocop, so it cannot
# simply be a GOH_CI_STEPS step like the shell checks: on a machine without
# `brew` it would either fail every gate forever (and get disabled) or be
# quietly absent (and look green while checking nothing). The item's rule is the
# one that matters here: **skip WITH A REASON, never pass silently** — so this
# prints WHY it did not run, and a caller reading only the exit code still
# learns that a real check was skipped.
#
# The exit code is non-zero when `brew` is missing or style fails, because a
# tap that cannot check itself should not be indistinguishable from a clean
# one. Set `TAP_STYLE_OPTIONAL=1` to downgrade the missing-`brew` case to a
# warning — for a machine that genuinely will never have Homebrew, and only
# there.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
    msg="SKIPPED: brew is not installed, so 'brew style' did not run over this tap."
    if [ "${TAP_STYLE_OPTIONAL:-0}" = "1" ]; then
        printf 'WARN: %s\n' "$msg"
        exit 0
    fi
    printf '%s\n' "$msg" >&2
    printf '  This is a SKIP, not a pass: the tap was not style-checked.\n' >&2
    exit 1
fi

exec brew style "$HERE"/Formula/*.rb "$HERE"/Casks/*.rb