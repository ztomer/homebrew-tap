cask "cadgoose" do
  version "1.83"
  sha256 "19f46cb04d1f20ab1a8cab04a0a297235c417e4914a0ed0823108bff7df059dd"

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
