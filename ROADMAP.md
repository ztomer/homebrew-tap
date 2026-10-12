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
- Gate: goh structural layer only (`tools/gate.sh`); green on 2026-10-12. Nothing in it reads Ruby.
  `brew style Formula/*.rb Casks/*.rb` reports 4 offenses (3 missing final newlines,
  `Casks/divoom-control.rb:11` redundant `depends_on macos: :big_sur`).

## Rulings

- Ruby DSL stays: listed under "Explicitly not Rust" in `../RUSTIFICATION_ROADMAP.md` §6.
- Apple silicon only: every cask carries `depends_on arch: :arm64` (house rule: 64-bit, macOS
  Apple silicon only).

## Phase 0: gate holes (S, one session)

Goal: a wrong formula or cask cannot reach `origin` silently.

- **T0.1 Tap consistency gate.** Add `tools/repo_gates.sh` (wired from `tools/gate.sh --full`) that
  checks, per file: every `resource` URL names the same tag as the main `url`/`version` (the
  `a0a1f59` class: multitop 0.49.0 shipped with agent resources pointed at v0.47.3), no two
  `sha256` lines in one file are equal (resource sha copied from the tarball), and file ends with a
  newline. Proof: a fixture with a mismatched resource tag and one with a duplicated sha both go
  red for their named reason.
- **T0.2 `brew style` in the gate**, then fix the 4 offenses it reports. Proof: gate red on today's
  tree, green after the fix. Risk: `brew style` needs the Homebrew Ruby; skip-with-reason when
  `brew` is absent, never pass silently.
- **T0.3 Bumps land through the gate.** Producers push to `origin` with the GitHub API or a temp
  clone, so this repo's hooks never run on them. Either the shared bump step (goh release-kit
  `tap`) runs `tools/gate.sh --full` on its clone before pushing, or a GitHub Action on this repo
  runs the same checks on push. Proof: a deliberately bad bump is refused. Depends on T0.1, T0.2.

## Phase 1: one bump path (M, spans producer repos)

Goal: one implementation of "bump a formula/cask", so a fix reaches every package.

- **T1.1** Move `antiknob`, `divoom-control`, `monitor` (multitop) and `CadGoose` onto goh
  release-kit step `tap`. The work happens in those repos. Track it here because the tap is
  where divergence shows. Proof: `git log --format=%s` on this repo shows one commit-message
  shape for every package after the next release of each.
- **T1.2** Retire `ztools/tools/upgrade_tap.py` once T1.1 lands. Its docstring already says it
  is not the release path.
- **T1.3 Review the one kill-by-name survivor.** `Casks/divoom-control.rb` uninstalls with
  `pkill -f 'Divoom.app/Contents/Frameworks/bin/divoom'`. It is seeded `unreviewed` in
  `kill_by_name_allow.json`. Replace it with `uninstall launchctl:` / `quit:` on the helpers' bundle
  ids, or a pidfile the app writes. Proof: the allowlist entry is deleted and the gate stays green.
  Risk: it needs divoom-control to give its helpers a stable identity first.

## Phase 2: hygiene (S)

- **T2.1** Keep the README table generated from or checked against `Formula/` + `Casks/`: a
  package added without a row (or a row with no file) goes red.

## Sources consolidated (2026-10-12)

- `.opencode/opencode-loop/ses_f7d57337cffebfLFllgW3z3VQR.json`: `{"jobs": []}`, no goal. Nothing
  to carry, so the loop dir was trashed. It is git-ignored via `.gitignore: .opencode/`.
- opencode db: project row `737c705650550a5ff2feb95c95365a0e2ceebc27` (0 sessions). Left for the
  coordinator.
- Claude CLI / desktop, Antigravity, Gemini CLI: no session for this repo. The `scripts`
  Gemini checkpoints mention this path only in a directory listing, so they are not this
  repo's.
- `../RUSTIFICATION_ROADMAP.md` §6: "not Rust" ruling, carried under Rulings.
- `../ROADMAP-consolidated.md`: no entry for this repo.
- `../backup/flatten-records/homebrew-tap.txt`: pre-flatten HEAD `1251d15` (233 commits, 2026-09-04),
  reference data, nothing open.
