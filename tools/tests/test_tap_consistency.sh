#!/usr/bin/env bash
# Tests for tools/tap_consistency.sh -- the gate that catches the a0a1f59 class:
# a formula that LOOKS bumped while its resource urls still name an old tag.
#
# WHY THIS FILE EXISTS. The gate's own header says it is "written as a plain
# per-file function so tools/tests/test_tap_consistency.sh can call it on a
# fixture and assert the failure says WHICH defect". That file was never
# written: the defects were proven by hand, in a session, and the proof died
# with the session. This is that file.
#
# The gate is COPIED into a fixture tree, because the README-parity check reads
# $HERE/README.md, $HERE/Formula and $HERE/Casks -- it can only be driven with
# a tree that is not the tap. The copy is taken from the real file at run
# time, so the test cannot drift from the gate it tests.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/tools" "$tmp/Formula" "$tmp/Casks" "$tmp/files"
cp "$HERE/tools/tap_consistency.sh" "$tmp/tools/tap_consistency.sh"
# shellcheck source=/dev/null
. "$tmp/tools/tap_consistency.sh"

fails=0

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

# ── the two clean shapes this tap ships stay green ──────────────────────────
cat >"$tmp/files/clean.rb" <<'EOF'
class Clean < Formula
  desc "a formula that pins its tag"
  homepage "https://github.com/o/r"
  url "https://github.com/o/r/archive/refs/tags/v0.55.0.tar.gz"
  sha256 "1111111111111111111111111111111111111111111111111111111111111111"
end
EOF
expect "a formula that pins the tag it declares" "" "$(tap_file_problems "$tmp/files/clean.rb")"

cat >"$tmp/files/clean_cask.rb" <<'EOF'
cask "clean" do
  version "1.2.3"
  url "https://example.com/Thing-v#{version}.dmg"
  sha256 "2222222222222222222222222222222222222222222222222222222222222222"
end
EOF
expect "a cask whose url interpolates its version" "" "$(tap_file_problems "$tmp/files/clean_cask.rb")"

# ── defect 1: a url that does not pin the version the file declares ─────────
cat >"$tmp/files/stale.rb" <<'EOF'
class Stale < Formula
  url "https://github.com/ztomer/multitop/archive/refs/tags/v0.55.0.tar.gz"
  sha256 "3333333333333333333333333333333333333333333333333333333333333333"
  resource "multitop-agent-x86_64" do
    url "https://github.com/ztomer/multitop/releases/download/v0.47.3/multitop-agent-x86_64-unknown-linux-musl"
    sha256 "4444444444444444444444444444444444444444444444444444444444444444"
  end
end
EOF
expect "a resource url left at an old tag (a0a1f59)" \
    "url names v0.47.3 but the file declares 0.55.0 (a0a1f59)" \
    "$(tap_file_problems "$tmp/files/stale.rb")"

cat >"$tmp/files/moving.rb" <<'EOF'
cask "moving" do
  version "1.0"
  url "https://example.com/latest/Thing.dmg"
  sha256 "5555555555555555555555555555555555555555555555555555555555555555"
end
EOF
expect "a url that names no version at all" \
    "url names no version tag (a moving target in a versioned tap)" \
    "$(tap_file_problems "$tmp/files/moving.rb")"

cat >"$tmp/files/noversion.rb" <<'EOF'
cask "noversion" do
  url "https://example.com/Thing.dmg"
  sha256 "6666666666666666666666666666666666666666666666666666666666666666"
end
EOF
expect "a file that declares no version" "no version declared" \
    "$(tap_file_problems "$tmp/files/noversion.rb")"

# ── defect 2: two shas in one file ─────────────────────────────────────────
cat >"$tmp/files/dupesha.rb" <<'EOF'
class Dupesha < Formula
  url "https://github.com/o/r/archive/refs/tags/v0.55.0.tar.gz"
  sha256 "7777777777777777777777777777777777777777777777777777777777777777"
  resource "agent" do
    url "https://github.com/o/r/releases/download/v0.55.0/agent"
    sha256 "7777777777777777777777777777777777777777777777777777777777777777"
  end
end
EOF
expect "a resource sha copied from the tarball's" \
    'sha256 "7777777777777777777777777777777777777777777777777777777777777777" appears more than once' \
    "$(tap_file_problems "$tmp/files/dupesha.rb")"

# ── defect 3: no trailing newline ──────────────────────────────────────────
printf 'cask "nonl" do\n  version "1.0"\n  sha256 "8"\nend' >"$tmp/files/nonl.rb"
expect "a file that does not end with a newline" "file does not end with a newline" \
    "$(tap_file_problems "$tmp/files/nonl.rb")"

# ── the membership helper can say ABSENT (the quiet direction) ─────────────
# A membership test that cannot say "absent" answers "present" to everything
# and passes forever. This is the calibration: both answers, from the same call.
expect "membership can say absent" "absent" \
    "$(contains_line "nope" "a" "b" && echo present || echo absent)"
expect "membership can say present" "present" \
    "$(contains_line "b" "a" "b" && echo present || echo absent)"

# ── README parity, both directions ─────────────────────────────────────────
cp "$tmp/files/clean.rb" "$tmp/Formula/clean.rb"
printf 'brew install ztomer/tap/clean\n' >"$tmp/README.md"
expect "a README row for every package on disk" "" "$(readme_problems)"

printf 'class Newpkg < Formula\nend\n' >"$tmp/Formula/newpkg.rb"
expect "a package with no README row" \
    "newpkg has a Formula/Cask but no README row (add one, or the file should not ship)" \
    "$(readme_problems)"
rm -f "$tmp/Formula/newpkg.rb"

printf 'brew install ztomer/tap/clean\nbrew install ztomer/tap/ghost\n' >"$tmp/README.md"
expect "a README row with no package" \
    "README documents ghost but there is no Formula/ghost.rb or Casks/ghost.rb" \
    "$(readme_problems)"

[ "$fails" -eq 0 ] || { printf '✗ %d tap_consistency test(s) failed\n' "$fails" >&2; exit 1; }
printf '✓ tap_consistency: every planted defect went red, the clean fixtures stayed green\n'
