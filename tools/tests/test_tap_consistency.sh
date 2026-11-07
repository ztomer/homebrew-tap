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
cp "$HERE/tools/tap_consistency.sh" "$HERE/tools/tap_files.sh" "$tmp/tools/"
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

# ── an untracked package file never ships (D.TAPDIRT) ───────────────────────
# A Formula/routines.rb for v0.15.0 sat untracked in the brew tap checkout for
# ten weeks: no release wrote it (goh's release.sh bumps through a temp clone),
# so it was a hand-write nobody committed, and the gate judged it as if it
# shipped. A package file git does not track is named as exactly that.
printf 'brew install ztomer/tap/clean\n' >"$tmp/README.md"
git -C "$tmp" init -q
git -C "$tmp" add Formula/clean.rb
expect "a tracked package is not flagged" "" "$(untracked_problems)"
printf 'class Stray < Formula\nend\n' >"$tmp/Formula/stray.rb"
expect "an untracked package file" \
    "Formula/stray.rb is untracked" \
    "$(untracked_problems)"
# The stray must be named as untracked and NOTHING ELSE: it never enters the
# README parity (which would send the operator to add a row for a package that
# does not ship) and is never judged as a package (D.TAPDIRT, second half).
expect "an untracked package file does not enter README parity" "" "$(readme_problems)"
stray_run="$(main 2>&1 || true)"
expect "an untracked package file is not judged as a package" "" \
    "$(printf '%s\n' "$stray_run" | grep -E '^(ok|FAIL): Formula/stray.rb' || true)"
expect "the run names the stray as untracked" "Formula/stray.rb is untracked" "$stray_run"
expect "README parity stays green beside a stray" \
    "ok: README.md documents every package on disk" "$stray_run"
rm -f "$tmp/Formula/stray.rb"

# Outside the tap's OWN checkout there is nothing to compare. The stray is
# PRESENT here: with it gone the check passes whatever the guard does, and a
# test that cannot fail proves nothing. A fixture NESTED in another repo is the
# case that fails without the guard (git answers for the parent repo and calls
# the stray untracked); a directory under no repo at all is the plain case.
rm -rf "$tmp/.git"
mkdir -p "$tmp/outer/fx/Formula"
git -C "$tmp/outer" init -q
printf 'class Stray < Formula\nend\n' >"$tmp/outer/fx/Formula/stray.rb"
real_here="$HERE"
HERE="$tmp/outer/fx"
expect "a fixture nested in another repo has nothing to compare" "" "$(untracked_problems)"
expect "a nested fixture still lists its package files" "stray.rb" "$(package_files)"
HERE="$real_here"
rm -rf "$tmp/outer"
mkdir -p "$tmp/nogit/Formula"
printf 'class Stray < Formula\nend\n' >"$tmp/nogit/Formula/stray.rb"
HERE="$tmp/nogit"
expect "outside any git checkout there is nothing to compare" "" "$(untracked_problems)"
HERE="$real_here"

[ "$fails" -eq 0 ] || { printf '✗ %d tap_consistency test(s) failed\n' "$fails" >&2; exit 1; }
printf '✓ tap_consistency: every planted defect went red, the clean fixtures stayed green\n'
