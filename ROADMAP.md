# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work
lives in `CHANGELOG.md` and in git history; this file holds what is OPEN.

## Context (measured 2026-10-19)

- 5 packages: `Formula/multitop.rb` (0.56.0), `Formula/ztools.rb` (3.9.0),
  `Casks/antiknob.rb` (0.15.1), `Casks/cadgoose.rb` (1.83),
  `Casks/divoom-control.rb` (0.41.2; the v0.41.3 release is in flight and had
  not landed in this repo when this was measured).
- The tap is a CONSUMER. Every bump is pushed straight to `origin` by the
  producer's release script, never from this checkout. On 2026-10-12 this
  checkout sat 14 commits behind `origin` and read as "every package stale,
  multitop agent shas wrong" until it was fetched.
- ONE implementation writes here now: goh's `tools/release-kit/tap_bump.sh`
  (T2.1). It clones the tap, moves the version, every url and every sha256
  TOGETHER, runs THIS tap's `tools/gate.sh --full` in the clone, and pushes
  the commit PINNED. A red gate pushes nothing.
- Gate: `tools/gate.sh --full` runs goh's `local_ci.sh` over the steps
  `.gatesrc` declares. Six steps, green on 2026-10-19: structural, the tap
  consistency check, the consistency test, `brew style`, the cask-floor test,
  the cask floor. `brew style` reports 5 files inspected, no offenses.

## Rulings

- Ruby DSL stays: listed under "Explicitly not Rust" in `../RUSTIFICATION_ROADMAP.md` §6.
- Apple silicon only: every cask carries `depends_on arch: :arm64` (house rule: 64-bit, macOS
  Apple silicon only).

## Phase 2: one bump path (M, spans producer repos)

Goal: one implementation of "bump a formula/cask", so a fix reaches every package.

- **T2.1 The stated proof, MEASURED on this repo's own history (2026-10-19).
  OPEN for the two packages that have not released since the move.** The
  item's proof was: "`git log --format=%s` on
  this repo shows one commit-message shape for every package after the next
  real release of each." The shape is goh's `tap_bump.sh` template --
  `git commit -qm "${NAME} ${TAG}"`
  (`gates_of_heck/tools/release-kit/tap_bump.sh:85`) -- so a bump lands as
  `<name> v<version>`.

  Measured over the commits since the move (2026-10-17):

  | package | tap commit(s) | message(s) | shape |
  | --- | --- | --- | --- |
  | ztools | `e85fe06` (v3.8.1), `c0976f3` (v3.9.0) | `ztools v3.8.1`, `ztools v3.9.0` | `<name> v<version>` |
  | multitop (monitor) | `4385954` (v0.56.0) | `multitop v0.56.0` | `<name> v<version>` |
  | cadgoose | `bd792ef` (v1.82), `fd57318` (v1.83) | `cadgoose v1.82`, `cadgoose v1.83` | `<name> v<version>` |
  | divoom-control | the v0.41.3 release is IN FLIGHT and has not landed in this repo | -- | OUTSTANDING |
  | antiknob | -- | -- | NO RELEASE SINCE THE MOVE |

  Three of the five have released since the move, and all three land the one
  shape. The other two are NOT claimed:
  **divoom-control's v0.41.3 release is in flight on 2026-10-19 and had not
  landed in this repo when this was measured** (its last tap commit is still
  `5645bdd` "divoom-control 0.41.2", the PRE-move shape, with no `v`); and
  **antiknob has NOT released since the move** -- its latest upstream release
  is still v0.15.1 (2026-10-09), and its last tap commit is still `4dd9b12`
  "antiknob 0.15.1" (2026-10-08), the PRE-move shape. The item stays open
  for those two, and closes for each when its next release lands in this
  repo.

  For contrast, the shapes BEFORE the move were five different ones:
  `multitop 0.55.0`, `divoom-control 0.41.2`, `antiknob 0.15.1`,
  `ztools v3.8.0`, and `Update CadGoose cask to version 1.81`. For
  cadgoose, multitop and divoom-control the message changed shape AT the
  move, so the shape is evidence the path changed, not just that a release
  happened.

  **The strength of this evidence, stated honestly, because the item asked for
  a commit MESSAGE and not a path:** ztools' shape is the same before and
  after the move -- goh's own `release.sh` wrote `"${TAP_NAME} ${TAG}"`
  before `tap_bump.sh` existed (`gates_of_heck` `bfac28b^`) -- so for ztools
  the message is the same whether or not the bump went through the new step.
  The PATH is proven separately, and not by this history:
  `ztools/tools/release.sh` execs goh's `release-kit/release.sh`, whose tap
  step calls `tap_bump.sh`.

- **T2.3 The kill-by-name survivor: the reason RE-MEASURED (2026-10-19), and
  it is still true. OPEN, and it is upstream's.** The one entry in
  `kill_by_name_allow.json` is `legitimate` and the `pkill` stays, because
  the reason is only as good as the day it was measured -- and today, against
  divoom-control v0.41.3, the reason still holds:

  * the helpers are still BARE BINARIES, not NSApplications. `divoomd` carries
    an embedded `__TEXT,__info_plist` with `CFBundleIdentifier
    com.divoom.divoomd` (`divoomd/build.rs`), which exists so macOS can
    attribute the daemon's Bluetooth permission and does not register the
    process with LaunchServices, so `quit:` cannot address it;
    `divoom-menubar` has no plist section at all (no `build.rs`).
  * the menu-bar agent is still spawned DETACHED --
    `subprocess.Popen(..., start_new_session=True)` at
    `divoom_gui/gui_main.py:467` -- and the daemon is spawned detached too
    (`divoom_client/daemon_client.py:236`). The agent does not self-terminate
    on the daemon's shutdown broadcast, so it orphans to launchd. The app's
    own shared-lifecycle quit path terminates it
    (`divoom_gui/gui_main.py:_terminate_menubar_agent`), but that path is
    skipped when the user turns `keep_daemon_alive` on, and a killed or
    crashed GUI never runs it.
  * there is still no pidfile and no LaunchAgent anywhere in divoom-control:
    the daemon's stable handle is the `/tmp/divoom.sock` control socket,
    which carries no process identity.

  So the item's stated risk is CONFIRMED, not assumed, and the cask's `pkill`
  and this allowlist entry both stay.

  **What is left is upstream and is not this repo's to do:** divoom-control
  must give the helpers a stable identity -- a real LaunchAgent, or a pidfile
  the app writes -- after which this cask drops the `pkill` and the
  allowlist entry is deleted. Until then the two stay, and the reason they
  stay is re-measured here, in the ROADMAP and in the allowlist entry itself.

## Sources consolidated

The 2026-10-12 consolidation (opencode loop and db row, the cross-project
roadmaps, the pre-flatten record) left nothing open; its record is
`git show be7f594:ROADMAP.md`. goh's Downstream notes (v0.27.0: hooks,
floors, 6.8 `tap_bump.sh`) are Phase 0, T1.3 and T2.1. The shipped record of
Phases 0, 1 and 3 is in `CHANGELOG.md` and in this repo's git history.
