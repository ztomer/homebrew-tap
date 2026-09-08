cask "cadgoose" do
  version "1.77"
  sha256 "9f847ad98f48b31d0f831a7232a854a9d9dd71adbc6874ac5be573339811c987"

  url "https://github.com/ztomer/CadGoose/releases/download/v#{version}/CadGoose-v#{version}.dmg"
  name "CadGoose"
  desc "Agentic overlay companion with multi-goose support and AI chat"
  homepage "https://github.com/ztomer/CadGoose"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "CadGoose.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/CadGoose.app"]
  end

  uninstall quit: "com.desktoppad.CadGoose"

  zap trash: [
    "~/Library/Application Support/CadGoose",
    "~/Library/Logs/CadGoose",
    "~/Library/Preferences/com.desktoppad.CadGoose.plist",
  ]
end
