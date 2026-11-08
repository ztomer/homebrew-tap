# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work is
pruned to git history and `CHANGELOG.md`; this file holds only what is OPEN.

## Open work

None. Every tracked item is closed (last: TAP.T21, `cc92f15`, 2026-11-08). New
work enters here with an id and a `Done when:` clause.

## Phases

None while nothing is open.

## Context

- Packages and versions: read them from the tree (`Formula/*.rb`, `Casks/*.rb`)
  after `git pull --ff-only`; they are not copied here because release bots
  move them.
- The tap is a CONSUMER: producers push bumps straight to `origin` through
  goh's `tools/release-kit/tap_bump.sh`, which runs this tap's
  `tools/gate.sh --full` in its clone and pushes nothing on red. Fetch before
  reading any version.
- Gate of record: `tools/gate.sh --full` (steps in `.gatesrc` `GOH_CI_STEPS`),
  run by the pre-push hook and, since `f033c40` (2026-11-08), by
  `.github/workflows/ci.yml` on every push and pull request.

## Rulings in force

- Ruby DSL stays (not a Rust candidate) — 2026-10-12, recorded in `be7f594`
  (its source, `RUSTIFICATION_ROADMAP.md`, no longer exists).
- Apple silicon only: every cask carries `depends_on arch: :arm64` — house
  rule 2026-08-17 (64-bit only; macOS Apple silicon only).
