#!/usr/bin/env bash
# Tests for tools/cask_floor.sh: a cask's `depends_on macos:` is held to the floor its
# producer WRITES (CadGoose: cmake/MacOSFloor.cmake, ROADMAP G0.18).
#
# The producer fetch is the one impure seam: each test redefines `fetch_producer_file`
# (and `codename_for`, except where the real Homebrew mapping is the subject), so no
# test needs the network. The real fetch is exercised by the gate step itself.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../cask_floor.sh
. "$HERE/tools/cask_floor.sh"

fails=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

expect() {  # expect <name> <needle|""> <output>
    local name="$1" needle="$2" out="$3"
    if [ -z "$needle" ] && [ -n "$out" ]; then
        printf '✗ %s: wanted green, got: %s\n' "$name" "$out" >&2; fails=$((fails + 1))
    elif [ -n "$needle" ] && [[ "$out" != *"$needle"* ]]; then
        printf '✗ %s: wanted an error naming %q, got: %s\n' "$name" "$needle" "${out:-(green)}" >&2
        fails=$((fails + 1))
    else
        printf '✓ %s\n' "$name"
    fi
}

cask() {  # cask <depends_on line(s)> -> path of a fixture cask at version 2.0
    local f="$tmp/c$RANDOM.rb"
    printf 'cask "x" do\n  version "2.0"\n%s\nend\n' "$1" >"$f"
    printf '%s' "$f"
}

# ── the cask clause, given a codename ─────────────────────────────────────────
expect "matching floor" "" "$(cask_floor_problems "$(cask '  depends_on macos: :tahoe')" tahoe)"
expect "another OS" "needs exactly \`depends_on macos: :tahoe\`" \
    "$(cask_floor_problems "$(cask '  depends_on macos: :sequoia')" tahoe)"
expect "no depends_on" "has none" "$(cask_floor_problems "$(cask '')" tahoe)"
expect "deprecated string form" "needs exactly" \
    "$(cask_floor_problems "$(cask '  depends_on macos: ">= :tahoe"')" tahoe)"
expect "two depends_on" "needs exactly" \
    "$(cask_floor_problems "$(cask $'  depends_on macos: :tahoe\n  depends_on macos: :tahoe')" tahoe)"

# ── the producer's floor, from its cmake ──────────────────────────────────────
expect "cmake floor read" "" "$([ "$(floor_from_cmake 'set(CG_MACOS_FLOOR "26.0")' CG_MACOS_FLOOR)" = 26.0 ] || echo bad)"
expect "cmake floor absent" "bad" "$(floor_from_cmake 'set(OTHER "26.0")' CG_MACOS_FLOOR || echo bad)"

# ── Homebrew is the codename authority (no hand table to drift) ───────────────
if command -v brew >/dev/null 2>&1; then
    expect "brew maps 26 to tahoe" "" "$([ "$(codename_for 26.0)" = tahoe ] || echo bad)"
    expect "brew refuses a non-version" "bad" "$(codename_for banana 2>/dev/null || echo bad)"
fi

# ── end to end through the seam: tag first, default branch when the tag predates the file ──
codename_for() { case "$1" in 26.0) echo tahoe ;; 27.0) echo golden_gate ;; *) return 1 ;; esac; }
fetch_producer_file() {  # repo ref path: the fixture producer has the floor file at v2.0 only
    case "$2" in
        v2.0) printf 'set(CG_MACOS_FLOOR "%s")\n' "${FIXTURE_TAG_FLOOR:-26.0}" ;;
        HEAD) printf 'set(CG_MACOS_FLOOR "27.0")\n' ;;
        *)    return 44 ;;   # 44: the file does not exist at that ref
    esac
}
f="$(cask '  depends_on macos: :tahoe')"
expect "end to end: tag floor holds" "" "$(check_cask x "$f" o/p cmake/F.cmake CG_MACOS_FLOOR 2>/dev/null)"
expect "end to end: tag floor raised" "golden_gate" \
    "$(FIXTURE_TAG_FLOOR=27.0 check_cask x "$f" o/p cmake/F.cmake CG_MACOS_FLOOR 2>/dev/null)"
f="$(cask '  depends_on macos: :tahoe')"; sed -i '' 's/"2.0"/"1.0"/' "$f"
expect "end to end: pre-floor tag reads the default branch" "golden_gate" \
    "$(check_cask x "$f" o/p cmake/F.cmake CG_MACOS_FLOOR 2>/dev/null)"
fetch_producer_file() { return 1; }
expect "end to end: fetch failure is red, not green" "could not read" \
    "$(check_cask x "$f" o/p cmake/F.cmake CG_MACOS_FLOOR 2>/dev/null)"

[ "$fails" -eq 0 ] || { printf '✗ %d cask_floor test(s) failed\n' "$fails" >&2; exit 1; }
printf '✓ cask_floor: every planted defect went red, the clean fixtures stayed green\n'
