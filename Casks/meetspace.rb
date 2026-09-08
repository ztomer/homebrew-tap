cask "meetspace" do
  version "1.3.1_meet2"
  sha256 "ef7d3f9f7cd9158c0a850147a7a810cd342789504f57f0c325ae25aeb206f5c8"

  url "https://github.com/ztomer/meetspace/releases/download/v#{version}/Meetspace_#{version.sub("_", "-")}_aarch64.dmg"
  name "Meetspace"
  desc "Local-first, privacy-respecting note-taking and meeting assistant"
  homepage "https://github.com/ztomer/meetspace"

  # Apple Silicon only — no Intel builds. Fails cleanly on x86_64 instead of 404.
  depends_on arch: :arm64
  depends_on macos: :sequoia

  # Installs the app bundle into /Applications
  app "Meetspace.app"

  # Automatically strips the quarantine bit recursively on post-install to bypass Apple Gatekeeper prompts
  postflight_steps do
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/Meetspace.app"]
  end

  uninstall quit: "com.meetspace.stable"

  # Cleans up application storage and settings on uninstall
  zap trash: [
    "~/.gemini/antigravity",
    "~/Library/Application Support/meetspace",
    "~/Library/Preferences/com.meetspace.stable.plist",
    "~/Library/Saved Application State/com.meetspace.stable.savedState",
  ]
end
