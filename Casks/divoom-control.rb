cask "divoom-control" do
  version "0.41.3"
  sha256 "73b15efef51c2f35c7e90883f79161758abe2a47941000e13dd7f6ec44a88823"

  url "https://github.com/ztomer/divoom_control/releases/download/v#{version}/Divoom-v#{version}.dmg"
  name "Divoom Control"
  desc "Control center for Divoom pixel displays (Pixoo/Tivoo/Ditoo/Timoo) over BLE+LAN"
  homepage "https://github.com/ztomer/divoom_control"

  depends_on arch: :arm64
  depends_on :macos

  app "Divoom.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/Divoom.app"]
  end

  # A clean upgrade/uninstall must stop everything the app spawns. Homebrew runs
  # these in a fixed order (quit before script), so:
  #   1. quit the GUI by bundle id — this triggers the app's own graceful daemon
  #      shutdown (divoomd exits, releasing /tmp/divoom.sock).
  #   2. pkill the helper binaries — both helpers are spawned DETACHED
  #      (start_new_session), so each sits in its OWN session, not the GUI's process
  #      group: it does not die with the GUI, and when the GUI exits it is reparented
  #      to launchd. It must be killed explicitly; this also reaps a stubborn
  #      divoomd. The pattern matches only
  #      Contents/Frameworks/bin/divoom{d,-menubar}, never the main
  #      Contents/MacOS/Divoom app. `|| true` so a no-match (nothing running) is
  #      not treated as a failure.
  #
  # THE APP ALREADY STOPS MOST OF THIS ITSELF (re-measured 2026-10-20 against
  # divoom-control v0.41.3). The menu-bar agent is NOT unconditionally orphaned:
  # the app's shared-lifecycle quit path terminates it
  # (divoom_gui/gui_main.py:_terminate_menubar_agent) and asks the daemon to shut
  # down over its control socket. That path is SKIPPED when the user sets
  # `keep_daemon_alive` (independent lifecycles — the tray is meant to survive the
  # GUI) or clears `quit_menubar_on_exit`
  # (divoom_lib/lifecycle_config.py:should_quit_menubar_on_exit), and it NEVER runs
  # if the GUI is killed or crashes. Those are the cases the pkill covers, and an
  # uninstall must stop a kept-alive tray the app deliberately kept running.
  #
  # WHY pkill AND NOT `quit:`, MEASURED (2026-10-15, re-measured 2026-10-20).
  # `quit:` reaches NSApplications by bundle id, and both helpers are BARE
  # BINARIES. `divoomd` does carry an embedded
  # `__TEXT,__info_plist` with CFBundleIdentifier `com.divoom.divoomd` (checked with
  # `otool` on the shipped Divoom.app) -- but that plist exists so macOS can attribute
  # the daemon's Bluetooth permission, and it does NOT register the process with
  # LaunchServices, so `quit:` cannot address it. `divoom-menubar` has no plist at all.
  # There is no LaunchAgent to unload and no pidfile to address either: the
  # daemon's stable handle is the /tmp/divoom.sock control socket, which carries
  # no process identity. Reviewed as `legitimate` in kill_by_name_allow.json
  # with this evidence; the real fix needs divoom-control to give these helpers a
  # stable identity (a LaunchAgent or a pidfile) and is ROADMAP T2.3.
  uninstall quit:   "com.divoom.control",
            script: {
              executable: "/bin/sh",
              args:       ["-c", "pkill -f 'Divoom.app/Contents/Frameworks/bin/divoom' || true"],
              sudo:       false,
            }

  zap trash: [
    "/tmp/divoom.sock",
    "/tmp/divoom_daemon.log",
    "~/.config/divoom-control",
  ]
end
