# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work
lives in `CHANGELOG.md` and in git history; this file holds what is OPEN.

## Context (measured 2026-10-24)

- 5 packages: `Formula/multitop.rb` (0.66.0), `Formula/ztools.rb` (3.9.2),
  `Casks/antiknob.rb` (0.15.2), `Casks/cadgoose.rb` (1.83),
  `Casks/divoom-control.rb` (0.41.7 — its v0.41.4 release landed in this repo
  on 2026-10-21 as `9bcddc6` carrying upstream commit `2010a31`, the helper
  identity T2.3 was waiting for; v0.41.5 `3faf923`, v0.41.6 `77ba0e3`, and
  v0.41.7 `9929748` followed).
- The tap is a CONSUMER. Every bump is pushed straight to `origin` by the
  producer's release script, never from this checkout. On 2026-10-12 this
  checkout sat 14 commits behind `origin` and read as "every package stale,
  multitop agent shas wrong" until it was fetched. It happened AGAIN on
  2026-10-21: this checkout sat ONE commit behind `origin` (`107d32b`
  "ztools v3.9.1") until it was fetched, and a producer pushed `3d7e868`
  ("multitop v0.62.0") while this plan was being written, so the versions
  above are read from the FETCHED tree (`git ls-remote origin refs/heads/main`
  vs the local HEAD) and re-read after every fetch.
- ONE implementation writes here by PATH: goh's `tools/release-kit/tap_bump.sh`
  (T2.1). It clones the tap, moves the version, every url and every sha256
  TOGETHER, runs THIS tap's `tools/gate.sh --full` in the clone, and pushes
  the commit PINNED. A red gate pushes nothing. Four divoom-control bumps did
  not come through it: `9bcddc6` (v0.41.4), `3faf923` (v0.41.5), `77ba0e3`
  (v0.41.6), and `9929748` (v0.41.7) were written BY HAND — each message is
  `cask: divoom-control v0.41.X - ...`, with a body and a `CHANGELOG.md`
  stanza, where `tap_bump.sh` writes exactly `"${NAME} ${TAG}"` and no body
  (`gates_of_heck/tools/release-kit/tap_bump.sh:85`). Every other post-move
  bump (through `cc92f15` antiknob v0.15.2) is that one-line shape with an EMPTY body (measured
  with `git log -1 --format=%b`).
- Gate: `tools/gate.sh --full` runs goh's `local_ci.sh` over the steps
  `.gatesrc` declares. SEVEN steps, green on 2026-10-24: structural, the tap
  consistency check, the consistency test, `brew style`, the cask-floor test,
  the cask's identity-based uninstall test, the cask floor. `brew style`
  reports 5 files inspected, no offenses. The tap has NO CI of its own —
  there is no workflow in this repository — so `tools/gate.sh --full` IS the
  gate of record: the pre-push hook runs it here, and every producer's
  `tap_bump.sh` runs it in its own clone before it pushes.

## Rulings

- Ruby DSL stays: listed under "Explicitly not Rust" in `../RUSTIFICATION_ROADMAP.md` §6.
- Apple silicon only: every cask carries `depends_on arch: :arm64` (house rule: 64-bit, macOS
  Apple silicon only).

## Sources consolidated

The 2026-10-12 consolidation (opencode loop and db row, the cross-project
roadmaps, the pre-flatten record) left nothing open; its record is
`git show be7f594:ROADMAP.md`. goh's Downstream notes (v0.27.0: hooks,
floors, 6.8 `tap_bump.sh`) were Phase 0, T1.3 and T2.1, all closed. The shipped record of
Phases 0, 1 and 3 is in `CHANGELOG.md` and in this repo's git history.
**T2.1 is closed and is no longer here** (2026-11-08): its shipped record is
the CHANGELOG stanza of that date (antiknob's v0.15.2 release, the fifth and
last package, landed as `cc92f15` in the script's shape).
**T2.3 is closed and is no longer here**: its shipped record is the CHANGELOG
stanzas of 2026-10-20 (the cask stops the helpers BY THEIR IDENTITY, and the
kill-by-name allowlist is gone) and 2026-10-21 (the producer's release that
carries the identity landed in this tap).
