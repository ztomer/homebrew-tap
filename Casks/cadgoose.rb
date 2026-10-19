cask "cadgoose" do
  version "1.82"
  sha256 "0ae7dd3d44718ce05743c3bc868809363a54c92769a825ea2400727e97dbb21c"

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
