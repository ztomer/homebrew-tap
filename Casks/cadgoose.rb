cask "cadgoose" do
  version "1.77"
  sha256 "9f847ad98f48b31d0f831a7232a854a9d9dd71adbc6874ac5be573339811c987"


  url "https://github.com/ztomer/CadGoose/releases/download/v#{version}/CadGoose-v#{version}.dmg"
  name "CadGoose"
  desc "Agentic overlay companion (Desktop Goose clone with multi-goose, custom behaviors, AI chat, etc.)"
  homepage "https://github.com/ztomer/CadGoose"

  app "CadGoose.app"

  postflight do
    system_command "xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/CadGoose.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/CadGoose",
    "~/Library/Logs/CadGoose",
    "~/Library/Preferences/com.desktoppad.CadGoose.plist",
  ]
end
