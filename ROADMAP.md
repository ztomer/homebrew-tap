# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work lives in git history.

## Context (measured 2026-10-12)

- 5 packages: `Formula/multitop.rb`, `Formula/ztools.rb`, `Casks/{antiknob,cadgoose,divoom-control}.rb`.
  All five are at their upstream's latest release (multitop 0.54.0, ztools 3.8.0, antiknob 0.15.1,
  CadGoose 1.81, divoom-control 0.41.1), and multitop's agent resource shas equal the v0.54.0
  release asset digests.
- The tap is a CONSUMER. Every bump is pushed straight to `origin` by the producer's release
  script, never from this checkout. On 2026-10-12 this checkout sat 14 commits behind `origin`
  and read as "every package stale, multitop agent shas wrong" until it was fetched.
- Five different bump implementations write here: `ztools` (goh `tools/release-kit/release.sh`
  step `tap`), `antiknob/release.sh` (gh API), `CadGoose` (a GitHub Action, verified by
  `scripts/push_release.sh`), `divoom-control/scripts/release.sh`, `monitor/release.sh` (multitop).
- Gate: goh structural layer only (`tools/gate.sh`); green on 2026-10-14 at `10ac042` under goh
  0.27.0 (hooks reinstalled in that commit). Nothing in it reads Ruby.
  `brew style Formula/*.rb Casks/*.rb` reports 4 offenses (3 missing final newlines,
  `Casks/divoom-control.rb:11` redundant `depends_on macos: :big_sur`).

## Rulings

- Ruby DSL stays: listed under "Explicitly not Rust" in `../RUSTIFICATION_ROADMAP.md` §6.
- Apple silicon only: every cask carries `depends_on arch: :arm64` (house rule: 64-bit, macOS
  Apple silicon only).

## Phase 0: wire in goh 0.27.0 -- closed

- P0.1 scanner floors: `1fe5f7e`.

## Phase 1: gate holes (S, one session)

Goal: a wrong formula or cask cannot reach `origin` silently.

- **T1.1 Tap consistency gate — DONE.** `tools/tap_consistency.sh` is a `GOH_CI_STEPS`
  step checking, per file, with each defect failing for its OWN reason:

  1. every `url` pins the version the file **declares** — the literal tag, or `#{version}`
     interpolation, which a Cask uses and which cannot drift by construction. A url with no
     tag at all (`/latest/`, a bare branch) is red: a moving target in a versioned tap.
  2. no two `sha256` lines in one file are equal (a resource sha copied from the tarball's).
  3. the file ends with a newline.

  **(1) is the `a0a1f59` class**: multitop 0.49.0 shipped with both agent `resource` URLs
  still naming v0.47.3, the formula looked bumped, and the artifacts were three releases
  stale. goh's `tap_bump.sh` produces this and (2) on today's files, which is what makes
  this load-bearing rather than hygiene.

  **It found three real defects on the tree the day it landed**: `Casks/antiknob.rb`,
  `Casks/divoom-control.rb` and `Formula/multitop.rb` all lacked a trailing newline. Fixed
  in the same commit — the gate is not "added and green", it is "added, went red three
  times, and those are fixed".

  Proved per defect, on the named shape: a resource URL moved to `v0.47.3` goes red with
  `url names v0.47.3 but the file declares 0.55.0 (a0a1f59)`; a duplicated sha goes red with
  the sha quoted; a missing newline goes red. Two version SHAPES exist here — CadGoose ships
  `1.81`, the others `0.15.1` — and the first draft's three-component pattern called the
  2-component cask unversioned, which is a gate crying wolf on a correct file.

  The gate also refused this repo's own first draft for `sed … | head -1` (an early-exit
  consumer under pipefail) — the house shape is `sed … > tmp; head -n1 < tmp`, which is
  what it now does.

- **T1.2 `brew style` in the gate — DONE.** `tools/brew_style.sh` is a `GOH_CI_STEPS`
  step, and it wraps the call rather than being a bare step, because `brew style` needs
  Homebrew's Ruby and cannot be one of the shell checks. The rule the item states —
  **skip with a reason, never pass silently** — is the whole of it: with no `brew` on
  PATH it prints `SKIPPED: brew is not installed, so 'brew style' did not run` and
  **exits 1**, so a tap that cannot check itself is never indistinguishable from a clean
  one. `TAP_STYLE_OPTIONAL=1` downgrades that to a warning for a machine that genuinely
  will never have Homebrew, and only there.

  **The offense count was stale: 1, not the 4 the item predicted** —
  `Casks/divoom-control.rb:11`, `depends_on macos: :big_sur`. Read before changing it,
  because deleting a platform constraint is the kind of edit that looks cosmetic and
  is not. The cop's own source settles it: it fires when the declared version is *at or
  below* `MacOSVersion.oldest_supported_os`, i.e. Homebrew already refuses anything
  older, so the line states nothing. Its autocorrect yields `depends_on :macos` — which
  keeps the requirement and stops restating a floor Homebrew enforces. `arch: :arm64` is
  untouched and still there.

  Proved in both directions: with `brew` the step runs and reports
  `5 files inspected, no offenses detected`; with PATH stripped it exits 1 saying it
  skipped, and with `TAP_STYLE_OPTIONAL=1` it exits 0 having said so.
- **T1.3 Bumps land through the gate — DONE, and its premise was stale.**
  goh 6.15 replaced `tap_bump.sh`'s two `sed` expressions with
  `tools/release-kit/tap_rewrite.py`, which reads the file as the DSL it is — the
  top-level `version`, `url` and `sha256`, and each `resource "NAME" do … end` block with
  its own — and moves them **together**. Verified on a scratch bare clone today (2026-10-15),
  both recorded defects no longer reproduce:

  * the cask bump moved `version "0.41.2"` → `"0.41.3"` alongside the digest, where the
    old `sed` left `version "0.41.1"` and brew would have fetched the OLD dmg against the
    NEW digest. A url interpolating `v#{version}` moves with the version line.
  * `tap_rewrite` refuses a shape it does not know *by name* rather than guessing.

  So the "shipped house-side, not yet safe here" note is out of date: the house fix landed.
  The proof this item asked for — "T1.1 refuses today's output" — no longer has anything to
  refuse, because those outputs are no longer produced. **T1.1 (above) remains the
  backstop** and was proven against exactly those two shapes when it landed: a resource url
  left at an old tag, and a resource sha set to the tarball's.

  One measured note from the same experiment: bumping `multitop` to a tag that was never
  released is refused by `tap_rewrite` itself — it cannot download the new agent resources
  and fails closed rather than writing a formula that points at 404s. That is the right
  direction, and it happens before this tap's gate is consulted at all.


## Phase 2: one bump path (M, spans producer repos)

Goal: one implementation of "bump a formula/cask", so a fix reaches every package.

- **T2.1** Move `antiknob` (`release.sh`), `divoom-control` (`scripts/release.sh`), `monitor`
  (multitop, `release.sh`), `CadGoose` (`scripts/push_release.sh`) and `ztools` (`tools/release.sh`
  with `tools/upgrade_tap.py`) onto `tap_bump.sh` (goh Downstream, 6.8). The work happens in those
  repos, after T1.3. Track it here because the tap is where divergence shows. Proof: `git log
  --format=%s` on this repo shows one commit-message shape for every package after the next
  release of each.
- **T2.2** Retire `ztools/tools/upgrade_tap.py` once T2.1 lands. Its docstring already says it
  is not the release path. **CLOSED 2026-10-14**, ahead of T2.1 rather than after it:
  `ztools` `5fff8d4` deleted the file, its `ARCHITECTURE.md` row, and adopted goh's
  `status-markers` in the same commit, so `tools/upgrade_tap.py` no longer exists and the one
  ungated door to this repo is shut. The ordering note stands as a lesson — the dependency was
  real and the item was still landable first, because the file had no callers and existed only
  as an alternative path.
- **T2.3 Review the one kill-by-name survivor.** `Casks/divoom-control.rb` uninstalls with
  `pkill -f 'Divoom.app/Contents/Frameworks/bin/divoom'`. It is seeded `unreviewed` in
  `kill_by_name_allow.json`. Replace it with `uninstall launchctl:` / `quit:` on the helpers' bundle
  ids, or a pidfile the app writes. Proof: the allowlist entry is deleted and the gate stays green.
  Risk: it needs divoom-control to give its helpers a stable identity first.

## Phase 3: hygiene (S)

- **T3.1** Keep the README table generated from or checked against `Formula/` + `Casks/`: a
  package added without a row (or a row with no file) goes red.

## Sources consolidated

The 2026-10-12 consolidation (opencode loop and db row, the cross-project roadmaps, the
pre-flatten record) left nothing open; its record is `git show be7f594:ROADMAP.md`. goh's
Downstream notes (v0.27.0: hooks, floors, 6.8 `tap_bump.sh`) are Phase 0, T1.3 and T2.1.
