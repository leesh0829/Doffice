cask "workman" do
  version "0.0.36"
  sha256 :no_check

  url "https://github.com/jjunhaa0211/MyWorkStudio/releases/download/v#{version}/WorkManApp.zip"
  name "WorkMan"
  desc "Gamified Claude Code session manager with pixel-art visualization"
  homepage "https://github.com/jjunhaa0211/MyWorkStudio"

  auto_updates true

  app "WorkManApp.app"

  zap trash: [
    "~/Library/Preferences/com.workman.app.plist",
    "~/Library/Application Support/WorkMan",
  ]
end
