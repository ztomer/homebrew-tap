# homebrew-tap roadmap

The ONE forward-looking plan for this tap (house rule #16). Completed work
lives in `CHANGELOG.md` and in git history; this file holds what is OPEN.

## Context (measured 2026-10-20)

- 5 packages: `Formula/multitop.rb` (0.57.0), `Formula/ztools.rb` (3.9.0),
  `Casks/antiknob.rb` (0.15.1), `Casks/cadgoose.rb` (1.83),
  `Casks/divoom-control.rb` (0.41.3 — its v0.41.3 release landed in this repo
  on 2026-10-19 as `be0259d`).
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

- **T2.1 The stated proof, MEASURED on this repo's own history (2026-10-20).
  FOUR of the five packages are PROVEN; the fifth, antiknob, has NOT released
  since the move.** The item's proof was: "`git log --format=%s` on
  this repo shows one commit-message shape for every package after the next
  real release of each." The shape is goh's `tap_bump.sh` template --
  `git commit -aqm "${NAME} ${TAG}"`
  (`gates_of_heck/tools/release-kit/tap_bump.sh:85`) -- so a bump lands as
  `<name> v<version>`.

  Measured with `git log --format=%s` over the commits since the move
  (2026-10-17):

  | package | tap commit(s) | message(s) | shape | verdict |
  | --- | --- | --- | --- | --- |
  | ztools | `e85fe06` (v3.8.1), `c0976f3` (v3.9.0) | `ztools v3.8.1`, `ztools v3.9.0` | `<name> v<version>` | lands the shape, but the shape is WEAK evidence here (see below) |
  | multitop (monitor) | `4385954` (v0.56.0), `3fc5861` (v0.57.0) | `multitop v0.56.0`, `multitop v0.57.0` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
  | cadgoose | `bd792ef` (v1.82), `fd57318` (v1.83) | `cadgoose v1.82`, `cadgoose v1.83` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
  | divoom-control | `be0259d` (v0.41.3) | `divoom-control v0.41.3` | `<name> v<version>` | PROVEN — the shape CHANGED at the move |
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
  closes for it when its next release lands in this repo.

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
  re-measured 2026-10-20:** `ztools v3.8.0` (`47e61ad`, 2026-10-10, pre-move)
  and `ztools v3.8.1` (`e85fe06`, 2026-10-18, post-move) are the same shape.
  For ztools the PATH is the evidence, not the shape, and the path is proven
  separately and not by this history: `ztools/tools/release.sh` execs goh's
  `release-kit/release.sh`, whose tap step calls `tap_bump.sh`
  (`gates_of_heck/tools/release-kit/release.sh:461`).

- **T2.3 The kill-by-name survivor: the reason RE-MEASURED (2026-10-20
  against divoom-control v0.41.3's own tree), and it is still true. OPEN, and
  it is upstream's.** The one entry in `kill_by_name_allow.json` is
  `legitimate` and the `pkill` stays, because the reason is only as good as the
  day it was measured -- and today the reason still holds:

  * the helpers are still BARE BINARIES, not NSApplications. `divoomd` carries
    an embedded `__TEXT,__info_plist` with `CFBundleIdentifier
    com.divoom.divoomd` (`divoomd/build.rs`, `divoomd/daemon_info.plist`),
    which exists so macOS can attribute the daemon's Bluetooth permission and
    does not register the process with LaunchServices, so `quit:` cannot address
    it; `divoom-menubar` has no plist section at all (no `build.rs`).
  * the menu-bar agent is still spawned DETACHED --
    `subprocess.Popen(..., start_new_session=True)` at
    `divoom_gui/gui_main.py:467` -- and the daemon is spawned detached too
    (`divoom_client/daemon_client.py:236`). The agent does not self-terminate
    on the daemon's shutdown broadcast.
  * there is still no pidfile and no LaunchAgent anywhere in divoom-control: a
    search of the whole v0.41.3 tree for `launchagent` / `launchctl` / a
    `.pid` path returns nothing, and the daemon's stable handle is the
    `/tmp/divoom.sock` control socket, which carries no process identity.

  **PRECISION, fixed 2026-10-20 -- the cask's comment said it wrong.** The
  menu-bar agent is NOT unconditionally orphaned. The app's own shared-lifecycle
  quit path terminates it (`divoom_gui/gui_main.py:_terminate_menubar_agent`),
  and asks the daemon to shut down over its control socket. That path is
  skipped when the user turns `keep_daemon_alive` on (independent lifecycles --
  the tray is meant to survive the GUI) or clears `quit_menubar_on_exit`
  (`divoom_lib/lifecycle_config.py:should_quit_menubar_on_exit`), and it never
  runs at all if the GUI is killed or crashes. So the orphan case is REAL, but
  it is not "every GUI quit leaves a stale tray icon", and the cask's comment
  now says so, as does the allowlist entry's reason.

  So the item's stated risk is CONFIRMED, not assumed, and the cask's `pkill`
  and this allowlist entry both stay.

  **What is left is upstream and is not this repo's to do:** divoom-control
  must give the helpers a stable identity -- a real LaunchAgent, or a pidfile
  the app writes -- after which this cask drops the `pkill` and the
  allowlist entry is deleted. Until then the two stay, and the reason they
  stay is re-measured here, in the ROADMAP, in the allowlist entry itself and
  in the cask's own comment.

## Sources consolidated

The 2026-10-12 consolidation (opencode loop and db row, the cross-project
roadmaps, the pre-flatten record) left nothing open; its record is
`git show be7f594:ROADMAP.md`. goh's Downstream notes (v0.27.0: hooks,
floors, 6.8 `tap_bump.sh`) are Phase 0, T1.3 and T2.1. The shipped record of
Phases 0, 1 and 3 is in `CHANGELOG.md` and in this repo's git history.
