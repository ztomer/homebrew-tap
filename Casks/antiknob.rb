cask "antiknob" do
  version "0.14.0"
  sha256 "4e68591ddef8746121f45052d82ae7728e20adc193579a09f1109eefb1f5ae8c"

  url "https://github.com/ztomer/antiknob/releases/download/v#{version}/Antiknob-v#{version}-aarch64.dmg"
  name "Antiknob"
  desc "Native configurator for the Anticater VK01 knob"
  homepage "https://github.com/ztomer/antiknob"

  # Apple Silicon only — Rust + SwiftUI build targets arm64 (binary minos 26.0).
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Antiknob.app"
  app "AntiknobDaemon.app"
  binary "bin/antiknob"
  binary "bin/antiknob-daemon"

  # Strip quarantine so Gatekeeper does not gate the self-signed build.
  # The apps AND the linked CLIs: binary artifacts keep the download's
  # quarantine bit, and a quarantined self-signed CLI hangs on first run
  # while Gatekeeper looks for a notarization ticket that does not exist.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/Antiknob.app"]
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/AntiknobDaemon.app"]
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{caskroom_path}}/{{version}}/bin/antiknob"]
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{caskroom_path}}/{{version}}/bin/antiknob-daemon"]
  end

  uninstall quit: [
    "com.antiknob.app",
    "com.antiknob.daemon",
  ]

  zap trash: "~/Library/Application Support/antiknob"
end