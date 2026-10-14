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

## Phase 0: wire in goh 0.27.0 (S, under an hour)

Goal: `tools/gate.sh --full` green at HEAD and pushed, with every scanner's floor declared. Exit:
`.gatesrc` sets the floors below, the gate prints no `[subject]` line, and `origin/main` = `main`.

Measured 2026-10-14 (`tools/gate.sh --full`, under 1 s): green, no red step. One advisory line.

- **P0.1 scanner floors.** Structural ends with `[subject] 10 scanner(s) declare no floor in
  .gatesrc …; this run read: GOH_EMOJI_MIN_FILES=21 GOH_CONFLICT_MARKERS_MIN_FILES=21
  GOH_FILE_LENGTH_MIN_FILES=6 GOH_SECRETS_MIN_FILES=21 GOH_SHELL_LINT_MIN_FILES=1
  GOH_EARLY_EXIT_PIPE_MIN_FILES=6 GOH_DEAD_AFTER_EXEC_MIN_FILES=6 GOH_BARE_HOOK_INDEX_MIN_FILES=6
  GOH_BARE_PYTHON_MIN_FILES=6 GOH_MD_LINKS_MIN_LINKS=6`. Paste each at or a little under its count
  (the tree is small: the count itself, or one under). Accept: the `[subject]` line is gone, and one
  floor raised one above its count turns `every scanner read its declared subject` red naming the
  key; then put it back. Size S.

## Phase 1: gate holes (S, one session)

Goal: a wrong formula or cask cannot reach `origin` silently.

- **T1.1 Tap consistency gate.** Add `tools/repo_gates.sh` (wired from `tools/gate.sh --full`) that
  checks, per file: every `resource` URL names the same tag as the main `url`/`version` (the
  `a0a1f59` class: multitop 0.49.0 shipped with agent resources pointed at v0.47.3), no two
  `sha256` lines in one file are equal (resource sha copied from the tarball), and file ends with a
  newline. Proof: a fixture with a mismatched resource tag and one with a duplicated sha both go
  red for their named reason. This is now load-bearing, not hygiene: goh's `tap_bump.sh` (below)
  produces exactly both defects on today's files, and this gate is the one it runs.
- **T1.2 `brew style` in the gate**, then fix the 4 offenses it reports. Proof: gate red on today's
  tree, green after the fix. Risk: `brew style` needs the Homebrew Ruby; skip-with-reason when
  `brew` is absent, never pass silently.
- **T1.3 Bumps land through the gate: shipped house-side, not yet safe here.** goh 6.8 (`bfac28b`)
  added `$GOH_DIR/tools/release-kit/tap_bump.sh --tap ztomer/homebrew-tap --formula|--cask NAME
  --tag vX.Y.Z --artifact PATH|URL`: it clones the tap, rewrites, runs this repo's `tools/gate.sh
  --full` in the clone and pushes pinned. Its rewrite does not fit this tap's shapes. Proven
  2026-10-14 by bumping a scratch bare clone to `v9.9.9`: on `Casks/divoom-control.rb` it changed
  the sha and left `version "0.41.1"` (the old dmg with the new digest); on `Formula/multitop.rb` it
  set both agent-resource shas to the tarball's and left their `releases/download/v0.54.0` URLs.
  This tap's gate passed both and they were pushed. (It rewrites `/tags/vX.tar.gz` URLs and every
  `sha256 "…"` line, never `version "…"`.)
  Its test fixture is a cask with a `/tags/` URL and no `version` line, so it passes. Reported to
  goh; fix it there (rewrite `version`, refuse a file with resources unless each resource is
  named), then T1.1 is the backstop. Proof: bumping each of the five files into a scratch bare clone
  (`--tap <path>`) leaves a file whose every URL names the new tag and whose shas are distinct, and
  T1.1 refuses today's output. Depends on T1.1.

## Phase 2: one bump path (M, spans producer repos)

Goal: one implementation of "bump a formula/cask", so a fix reaches every package.

- **T2.1** Move `antiknob` (`release.sh`), `divoom-control` (`scripts/release.sh`), `monitor`
  (multitop, `release.sh`), `CadGoose` (`scripts/push_release.sh`) and `ztools` (`tools/release.sh`
  with `tools/upgrade_tap.py`) onto `tap_bump.sh` (goh Downstream, 6.8). The work happens in those
  repos, after T1.3. Track it here because the tap is where divergence shows. Proof: `git log
  --format=%s` on this repo shows one commit-message shape for every package after the next
  release of each.
- **T2.2** Retire `ztools/tools/upgrade_tap.py` once T2.1 lands. Its docstring already says it
  is not the release path.
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
