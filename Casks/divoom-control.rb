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
  #   2. pkill the helper binaries — the menu-bar agent is spawned detached
  #      (start_new_session) and orphans to launchd when the GUI quits, so it must
  #      be killed explicitly; this also reaps a stubborn divoomd. The pattern
  #      matches only Contents/Frameworks/bin/divoom{d,-menubar}, never the main
  #      Contents/MacOS/Divoom app. `|| true` so a no-match (nothing running) is
  #      not treated as a failure.
  #
  # WHY pkill AND NOT `quit:`, MEASURED (2026-10-15). `quit:` reaches NSApplications
  # by bundle id, and both helpers are BARE BINARIES. `divoomd` does carry an embedded
  # `__TEXT,__info_plist` with CFBundleIdentifier `com.divoom.divoomd` (checked with
  # `otool` on the shipped Divoom.app) -- but that plist exists so macOS can attribute
  # the daemon's Bluetooth permission, and it does NOT register the process with
  # LaunchServices, so `quit:` cannot address it. `divoom-menubar` has no plist at all.
  # The menubar agent is spawned detached (start_new_session) and orphans to launchd
  # when the GUI quits, so there is no LaunchAgent to unload either, and there is no
  # pidfile: the daemon's stable handle is the /tmp/divoom.sock control socket, which
  # carries no process identity. Reviewed as `legitimate` in kill_by_name_allow.json
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
