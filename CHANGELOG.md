# Changelog

What shipped in this tap. The ROADMAP holds only what is OPEN; what is DONE
lives here and in the git history, because a per-feature plan graveyard rots
and misleads a later session (house rule).

The tap's own history before 2026-10-14 is in the git log -- the house gates
were wired on 2026-09-14 (`abf0b36`) and the bump history goes back to
`3d3eea6` (2026-09-04, a flatten of 233 commits). This file starts where the
tap began gating its own bumps.

## The bump path, proved by four releases; and the cask's comment, corrected _(2026-10-20)_

T2.1's proof was "the next real release of each package lands one
commit-message shape". Four of the five have now released since the move, and
the ROADMAP's table says so with the commits that carry it. The fifth,
antiknob, has NOT released since 2026-10-17, so its half is still outstanding
and is not implied anywhere.

The cask's comment about the menu-bar agent was wrong in the way a comment can
be wrong: it said the agent "orphans to launchd when the GUI quits", which
reads as "every GUI quit leaves a stale tray icon". The app's own
shared-lifecycle quit path terminates it.

**What shipped**

- `ROADMAP.md` T2.1, re-measured 2026-10-20 with `git log --format=%s`: the
  table now carries divoom-control's `be0259d` "divoom-control v0.41.3" -- its
  proof CLOSED, because the message changed shape AT the move (its last
  pre-move bump was `5645bdd` "divoom-control 0.41.2", no `v`). antiknob's row
  says plainly that it has NOT released since the move: latest upstream tag
  still v0.15.1 (2026-10-09), last tap commit still `4dd9b12` "antiknob
  0.15.1" (2026-10-08), the PRE-move shape.
- `ROADMAP.md` T2.1's multitop row carries a SECOND release: `3fc5861`
  "multitop v0.57.0" landed in this repo while this round was in flight, and
  it carries the same `<name> v<version>` shape as `4385954`
  "multitop v0.56.0". A producer bumping the tap mid-round is the path
  working, not an accident.
- `ROADMAP.md` T2.1 keeps ztools' caveat, re-measured and still true: ztools'
  shape is IDENTICAL before and after the move (goh's old `release.sh` wrote
  `"${TAP_NAME} ${TAG}"` -- `gates_of_heck` `bfac28b^`), so for ztools the
  PATH is the evidence, not the shape. The path is proven separately:
  `ztools/tools/release.sh` execs goh's `release-kit/release.sh`, whose tap
  step calls `tap_bump.sh`.
- `Casks/divoom-control.rb`: the `pkill` comment now says what is true. Both
  helpers are spawned DETACHED, so each sits in its own session, not the GUI's
  process group, and does not die with the GUI -- but the app's own
  shared-lifecycle quit path DOES terminate the menu-bar agent
  (`divoom_gui/gui_main.py:_terminate_menubar_agent`) and asks the daemon to
  shut down over its control socket. That path is skipped when the user sets
  `keep_daemon_alive` or clears `quit_menubar_on_exit`, and it never runs at
  all if the GUI is killed or crashes. The `pkill` covers exactly those cases.
- `kill_by_name_allow.json`: the entry's reason carries the same precision and
  the 2026-10-20 re-measurement (against divoom-control v0.41.3's own tree,
  not HEAD).
- `.gatesrc`: its comment still said "1 entries, 1 unreviewed" -- true on
  2026-09-23, stale since the entry was reviewed on 2026-10-15. It now says
  1 entry, 0 unreviewed.

**What deliberately didn't ship**

- The divoom-control cask's `pkill`, and its `kill_by_name_allow.json` entry.
  RE-MEASURED 2026-10-20 against divoom-control v0.41.3's own tree: still no
  LaunchAgent and still no pidfile (a search of the whole tag for `launchagent`
  / `launchctl` / a `.pid` path returns nothing), `divoomd`'s embedded plist is
  still only a Bluetooth-TCC attribution plist, and `divoom-menubar` still has
  no plist section. The real fix is upstream; the measurement is in ROADMAP
  T2.3.

**Tests**: the tap's own gate, 6 steps green -- structural, the tap consistency
check, the consistency test, `brew style` (5 files, no offenses), the cask-floor
test, the cask floor. The kill-by-name check still reports "no kill by name,
1 allowlisted".

**Followups**: ROADMAP T2.1 stays open for antiknob alone -- its next release
is the proof, and nothing in this repo can hurry it. ROADMAP T2.3 stays open
and is upstream's: divoom-control must give its helpers a stable identity (a
real LaunchAgent, or a pidfile the app writes) before the `pkill` and the
allowlist entry can go.

## The consistency gate gets the test it always claimed to have _(2026-10-19)_

The tap's gate had a step with no test. `tools/tap_consistency.sh`'s header
says it is "written as a plain per-file function so
`tools/tests/test_tap_consistency.sh` can call it on a fixture and assert the
failure says WHICH defect" -- and that file has never existed here
(`git log --all -- tools/tests/` shows only `test_cask_floor.sh`). The three
defects were proven by hand, in a session, and the proof died with the
session.

**What shipped**

- `tools/tests/test_tap_consistency.sh`: the two clean shapes this tap ships
  stay green (a formula that pins the tag it declares; a cask whose url
  interpolates `#{version}`), and each defect goes red naming ITSELF -- a
  resource url left at an old tag (the a0a1f59 class), a url that names no
  version at all (a moving target), a file that declares no version, two
  equal `sha256` lines, a missing trailing newline -- plus README parity in
  BOTH directions (a package with no row, a row with no package).
- The membership helper's QUIET direction is calibrated: `contains_line` must
  be able to say "absent". A membership test that cannot say absent answers
  "present" to everything and passes forever, which is the one failure a
  reviewer cannot see.
- `.gatesrc`: `bash tools/tests/test_tap_consistency.sh` is a declared step,
  so the tap's own gate runs it -- here, and in the clone every producer's
  `tap_bump.sh` makes before it pushes a bump.
- `.gatesrc`: the two scanners that read something and declared NO floor now
  declare one -- `GOH_TAP_WRITES_MIN_FILES=9` (read 11) and
  `GOH_UNREAPED_SPAWN_MIN_FILES=1` (read 2). Phase 0's item ("every scanner
  declares its floor") was unfinished for these two, and the gate said so on
  every run: "a scan that stops reading would pass".
- ROADMAP: T2.1's stated proof, measured on this repo's own history, and
  T2.3's reason re-measured against divoom-control v0.41.3.

**What deliberately didn't ship**

- The divoom-control cask's `pkill`, and its `kill_by_name_allow.json` entry.
  divoom-control still gives its helpers no stable identity -- no LaunchAgent,
  no pidfile -- so the reason the cask records is still true, and dropping the
  kill would leave a stale menu-bar agent behind. The fix is upstream; the
  measurement is in ROADMAP T2.3.

**Tests**: the tap's own gate, 6 steps green -- structural, the tap
consistency check, the consistency test, `brew style` (5 files, no offenses),
the cask-floor test, the cask floor. The new test was proven to BITE: five
mutations of the gate it tests (the duplicate-sha check removed, the
url-version check removed, the membership helper made always-present, the
README parity removed, the trailing-newline check removed) each turned it red,
and the unmutated gate stayed green. The new floors bite too: a floor above
the count read is red, naming the key, the floor and the count.

**Followups**: two of the five packages have not released since the bump path
moved, so their halves of T2.1's proof are still outstanding: antiknob (its
latest upstream release is still v0.15.1, 2026-10-09) and divoom-control
(whose v0.41.3 release was in flight and had not landed in this repo when the
proof was measured). ROADMAP T2.1. (SUPERSEDED 2026-10-20: divoom-control's
v0.41.3 did land in this repo, so only antiknob's half is outstanding.)

## The tap's gate runs the steps it declares _(2026-10-18)_

`tools/gate.sh --full` ran goh's structural layer alone, so the steps named in
`.gatesrc`'s `GOH_CI_STEPS` were declared and executed by nothing -- and the
line named a `rust_gate.sh` this tap has no Rust for, glued to `structural.sh`
by a missing colon. `--full` now runs goh's `local_ci.sh` over the declared
steps, structural first.

**What shipped**: the `--full` branch in `tools/gate.sh` and the corrected
`GOH_CI_STEPS` (`731d9a1`); `tools/cask_floor.sh`, which holds
`Casks/cadgoose.rb`'s `depends_on macos:` to the floor CadGoose writes in
`cmake/MacOSFloor.cmake`, with Homebrew (`MacOSVersion#to_sym`) as the
codename authority -- the clause used to run in CadGoose against a drifted
copy of this cask, and that copy is deleted -- and its test
`tools/tests/test_cask_floor.sh`; and `tools/brew_style.sh` styling a copy
under `$TMPDIR`, because `brew style` drops Homebrew's config under a hidden
path component and the push gate reported 10 offenses on clean files
(`b03dc29`).

**Tests**: `tools/tests/test_cask_floor.sh` (red before the script existed);
planting `depends_on macos: :sequoia` turns `tools/gate.sh --full` red.

## brew style in the gate _(2026-10-15)_

`tools/brew_style.sh` wraps `brew style` rather than being a bare step,
because `brew style` needs Homebrew's Ruby and cannot be one of the shell
checks. The rule the item states -- skip with a reason, never pass silently
-- is the whole of it: with no `brew` on PATH it prints `SKIPPED: brew is not
installed, so 'brew style' did not run` and EXITS 1, so a tap that cannot
check itself is never indistinguishable from a clean one.
`TAP_STYLE_OPTIONAL=1` downgrades that to a warning, and only for a machine
that genuinely will never have Homebrew.

**What shipped**: the step, and the ONE offense where the item predicted four:
`Casks/divoom-control.rb:11`, `depends_on macos: :big_sur`. The cop fires
when the declared version is at or below `MacOSVersion.oldest_supported_os`,
so the line stated nothing Homebrew does not already enforce; its autocorrect
yields `depends_on :macos`, which keeps the requirement and stops restating
the floor. `arch: :arm64` is untouched and still there.

**Tests**: with `brew`, the step runs and reports `5 files inspected, no
offenses detected`; with PATH stripped it exits 1 saying it skipped; with
`TAP_STYLE_OPTIONAL=1` it exits 0 having said so.

## The tap consistency gate _(2026-10-15)_

`tools/tap_consistency.sh` checks, per file, each defect failing for its OWN
reason: every `url` pins the version the file DECLARES -- the literal tag, or
`#{version}` interpolation, which a Cask uses and which cannot drift by
construction, while a url with no tag at all (`/latest/`, a bare branch) is
red, a moving target in a versioned tap; no two `sha256` lines in one file are
equal (a resource sha copied from the tarball's); and the file ends with a
newline.

This is the `a0a1f59` class: multitop 0.49.0 shipped with both agent
`resource` URLs still naming v0.47.3 -- the formula looked bumped, the
artifacts were three releases stale. goh's `tap_bump.sh` produced both of the
first two defects on the files of the day, which is what makes this
load-bearing rather than hygiene.

**What shipped**: the step, and the three real defects it found on the tree
the day it landed -- `Casks/antiknob.rb`, `Casks/divoom-control.rb` and
`Formula/multitop.rb` all lacked a trailing newline, fixed in the same commit.
The gate is not "added and green", it is "added, went red three times, and
those are fixed".

**What deliberately didn't ship**: a test of the gate's own. Added 2026-10-19
(see the top stanza) -- the header named a test file that never existed.

## The README is checked against the packages that ship _(2026-10-15)_

`tools/tap_consistency.sh` checks the README against the packages on disk: a
package with no row goes red, and a row with no file goes red. The pairing is
read from the INSTALL COMMAND, not the display name -- the names are prose
("Divoom Control", "ZTools") while the command carries the token brew resolves
("brew install --cask ztomer/tap/divoom-control"); matching on the pretty name
would need a hand-maintained synonym table, which is the same drift in a
different file.

**What shipped**: the check. The tree was already consistent -- 5 rows, 5
files -- which is exactly why nothing was checking it.

**What deliberately didn't ship**: two bugs this check had before it was
proven, both fixed in the same commit and both worth keeping. `printf ... |
grep -qx` is the early-exit-pipe defect this tap's own gate exists to catch,
and this repo's gate caught it here on the first attempt. And the membership
helper read its needle with `${!#}`, which does not work on the bash 3.2 that
ships on macOS: every test answered "present", so the check was wrong in the
QUIET direction and would have passed forever. Needle-first now, and the
calibration is re-run after every change to it.

## The kill-by-name survivor, reviewed _(2026-10-15)_

`kill_by_name_allow.json` had one entry, `unreviewed` since the gate was
seeded on 2026-09-23, and the gate counted it as debt. It is now
`legitimate`, with the reason MEASURED rather than assumed, and the evidence
is in the cask's own comment, because a reader of the file should not have to
come to the ROADMAP to find out why a kill-by-name is there.

**What shipped**: the review. `uninstall quit:` addresses NSApplications by
bundle id, and both helpers are BARE BINARIES: `divoomd` carries an embedded
`__TEXT,__info_plist` with `CFBundleIdentifier com.divoom.divoomd`, but that
plist exists so macOS can attribute the daemon's Bluetooth permission and
does not register the process with LaunchServices, so `quit:` cannot reach it;
`divoom-menubar` has no plist section at all. The menu-bar agent is spawned
detached and orphans to launchd when the GUI quits, so there is no LaunchAgent
to unload either; and there is no pidfile: the daemon's stable handle is the
`/tmp/divoom.sock` control socket, which carries no process identity.

**What deliberately didn't ship**: dropping the `pkill`. The real fix is
upstream and is not this repo's to do: divoom-control must give the helpers a
stable identity -- a real LaunchAgent, or a pidfile the app writes -- after
which the cask drops the `pkill` and the allowlist entry is deleted. The
pattern is as narrow as the need: `-f` matches the full command line and the
string is the installed app's own helper path, so it cannot match the main app
at `Contents/MacOS/Divoom`, and `|| true` makes a no-match a non-failure.

## ztools retired its ungated tap door _(2026-10-14)_

`ztools/tools/upgrade_tap.py` was a second door into this tap that no gate
ran. `ztools` `5fff8d4` deleted the file, its `ARCHITECTURE.md` row, and
adopted goh's `status-markers` in the same commit, so the one ungated door to
this repo is shut.

**What shipped**: nothing in this repo -- the file lived in the producer. The
record is here so the next reader does not go looking for it.

**Note**: it landed AHEAD of T2.1 rather than after it. The dependency was
real and the item was still landable first, because the file had no callers
and existed only as an alternative path.

## One bump path _(2026-10-17)_

All five producers moved onto goh's `tools/release-kit/tap_bump.sh`:
divoom-control `cee1cc4`, monitor `dccdc7a`, ztools (goh's release kit,
`--tap`), antiknob `4e6092b`, CadGoose `84a40b4` -- whose CI step that pushed
with a PAT is deleted, so `HOMEBREW_TAP_TOKEN` is unused and can be removed
from that repo's secrets. antiknob and CadGoose were proved against a scratch
bare clone of this tap: the current release is a no-op, a new version rewrites
version + sha256 and passes this repo's gate.

**What deliberately didn't ship**: the proof. It needs each product's next
real release, and it is measured in ROADMAP T2.1.

## Every scanner declares its floor _(2026-10-14)_

goh 0.27.0 gives every scanner a floor: a full-scope scan that reads less than
the floor has lost its subject and is red, not clean. `.gatesrc` declares one
per scanner -- nine tenths of what each read on 2026-10-14, the house rule.
Lower a floor with the tree, in the same commit, never to absorb a scan that
went blind.
