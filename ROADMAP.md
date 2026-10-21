# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work
lives in `CHANGELOG.md` and in git history; this file holds what is OPEN.

## Context (measured 2026-10-21)

- 5 packages: `Formula/multitop.rb` (0.61.1), `Formula/ztools.rb` (3.9.1),
  `Casks/antiknob.rb` (0.15.1), `Casks/cadgoose.rb` (1.83),
  `Casks/divoom-control.rb` (0.41.4 — its v0.41.4 release landed in this repo
  on 2026-10-21 as `9bcddc6`, and that release carries upstream commit
  `2010a31`, the helper identity T2.3 was waiting for).
- The tap is a CONSUMER. Every bump is pushed straight to `origin` by the
  producer's release script, never from this checkout. On 2026-10-12 this
  checkout sat 14 commits behind `origin` and read as "every package stale,
  multitop agent shas wrong" until it was fetched. It happened AGAIN on
  2026-10-21: this checkout sat ONE commit behind `origin` (`107d32b`
  "ztools v3.9.1") until it was fetched, so the versions above are read from
  the FETCHED tree (`git ls-remote origin refs/heads/main` vs the local HEAD).
- ONE implementation writes here by PATH: goh's `tools/release-kit/tap_bump.sh`
  (T2.1). It clones the tap, moves the version, every url and every sha256
  TOGETHER, runs THIS tap's `tools/gate.sh --full` in the clone, and pushes
  the commit PINNED. A red gate pushes nothing. ONE bump did not come through
  it: `9bcddc6` (divoom-control v0.41.4) was written BY HAND — its message is
  `cask: divoom-control v0.41.4 - the hot channel reaches the devices the
  app's settings name`, with a body, where `tap_bump.sh` writes exactly
  `"${NAME} ${TAG}"` and no body
  (`gates_of_heck/tools/release-kit/tap_bump.sh:85`). Every other bump in
  T2.1's table is that one-line shape with an EMPTY body (measured with
  `git log -1 --format=%b`).
- Gate: `tools/gate.sh --full` runs goh's `local_ci.sh` over the steps
  `.gatesrc` declares. SEVEN steps, green on 2026-10-21: structural, the tap
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

## Phase 2: one bump path (M, spans producer repos)

Goal: one implementation of "bump a formula/cask", so a fix reaches every package.

- **T2.1 The stated proof, MEASURED on this repo's own history (re-measured
  2026-10-21; first measured 2026-10-20). FOUR of the five packages are
  PROVEN; the fifth, antiknob, has NOT released since the move.** The item's
  proof was: "`git log --format=%s` on this repo shows one commit-message
  shape for every package after the next real release of each." The shape is
  goh's `tap_bump.sh` template -- `git commit -aqm "${NAME} ${TAG}"`
  (`gates_of_heck/tools/release-kit/tap_bump.sh:85`) -- so a bump lands as
  `<name> v<version>`.

  Measured with `git log --format=%s` over the commits since the move
  (2026-10-17):

  | package | tap commit(s) | message(s) | shape | verdict |
  | --- | --- | --- | --- | --- |
  | ztools | `e85fe06` (v3.8.1), `c0976f3` (v3.9.0), `107d32b` (v3.9.1) | `ztools v3.8.1`, `ztools v3.9.0`, `ztools v3.9.1` | `<name> v<version>` | lands the shape, but the shape is WEAK evidence here (see below) |
  | multitop (monitor) | `4385954` (v0.56.0), `3fc5861` (v0.57.0), `c7d5b87` (v0.58.0), `621854f` (v0.58.1), `3412ec7` (v0.59.0), `7239340` (v0.60.0), `77b054c` (v0.61.0), `945f371` (v0.61.1) | `multitop v0.56.0` … `multitop v0.61.1` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
  | cadgoose | `bd792ef` (v1.82), `fd57318` (v1.83) | `cadgoose v1.82`, `cadgoose v1.83` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
  | divoom-control | `be0259d` (v0.41.3) | `divoom-control v0.41.3` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
  | divoom-control, SECOND bump | `9bcddc6` (v0.41.4) | `cask: divoom-control v0.41.4 - the hot channel reaches the devices the app's settings name` | NOT the script's shape: a `cask: ` prefix, a suffix, and a body | NOT the path — it was written by hand (see Context) |
  | antiknob | -- | -- | -- | OUTSTANDING — NO RELEASE SINCE THE MOVE |

  **divoom-control's half of the proof CLOSED on 2026-10-19.** Its v0.41.3
  release landed here as `be0259d` "divoom-control v0.41.3" — the
  `<name> v<version>` shape, where its last PRE-move bump was `5645bdd`
  "divoom-control 0.41.2" (no `v`). The message changed shape AT the move, so
  it is evidence the path changed, not merely that a release happened.

  **antiknob is NOT claimed, and the proof is not implied.** It has not
  released since the move: its latest upstream tag is still v0.15.1 (2026-10-09)
  and its last tap commit is still `4dd9b12` "antiknob 0.15.1" (2026-10-08),
  the PRE-move shape (no `v`). The item stays open for antiknob alone, and
  closes for it when its next release lands in this repo. **Who can move it:
  the antiknob producer's own release script, in the antiknob repository
  (another repo, another session). Nothing here can hurry it, and nothing
  here is waiting on the owner.**

  For contrast, the shapes BEFORE the move were five different ones:
  `multitop 0.55.0`, `divoom-control 0.41.2`, `antiknob 0.15.1`,
  `ztools v3.8.0`, and `Update CadGoose cask to version 1.81`. For
  cadgoose, multitop and divoom-control the message changed shape AT the
  move, so the shape is evidence the path changed, not just that a release
  happened.

  **The strength of this evidence, stated honestly, because the item asked for
  a commit MESSAGE and not a path:** ztools' shape is the same before and
  after the move -- goh's own `release.sh` wrote `"${TAP_NAME} ${TAG}"`
  before `tap_bump.sh` existed (`gates_of_heck` `bfac28b^`,
  `tools/release-kit/release.sh:483`) -- so for ztools the message is the same
  whether or not the bump went through the new step. **This caveat STILL HOLDS,
  re-measured 2026-10-21:** `ztools v3.8.0` (`47e61ad`, 2026-10-10, pre-move)
  and `ztools v3.8.1` (`e85fe06`, 2026-10-18, post-move) are the same shape,
  and so is the third one, `ztools v3.9.1` (`107d32b`, 2026-10-21).
  For ztools the PATH is the evidence, not the shape, and the path is proven
  separately and not by this history: `ztools/tools/release.sh` execs goh's
  `release-kit/release.sh`, whose tap step calls `tap_bump.sh`
  (`gates_of_heck/tools/release-kit/release.sh:461`).

## Sources consolidated

The 2026-10-12 consolidation (opencode loop and db row, the cross-project
roadmaps, the pre-flatten record) left nothing open; its record is
`git show be7f594:ROADMAP.md`. goh's Downstream notes (v0.27.0: hooks,
floors, 6.8 `tap_bump.sh`) are Phase 0, T1.3 and T2.1. The shipped record of
Phases 0, 1 and 3 is in `CHANGELOG.md` and in this repo's git history.
**T2.3 is closed and is no longer here**: its shipped record is the CHANGELOG
stanzas of 2026-10-20 (the cask stops the helpers BY THEIR IDENTITY, and the
kill-by-name allowlist is gone) and 2026-10-21 (the producer's release that
carries the identity landed in this tap).
