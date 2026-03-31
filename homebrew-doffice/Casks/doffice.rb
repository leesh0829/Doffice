cask "doffice" do
  version "0.0.41"
  sha256 :no_check

  url "https://github.com/jjunhaa0211/MyWorkStudio/releases/download/v#{version}/DofficeApp.zip"
  name "Doffice"
  desc "Gamified Claude Code session manager with pixel-art visualization"
  homepage "https://github.com/jjunhaa0211/MyWorkStudio"

  auto_updates true

  app "DofficeApp.app"

  zap trash: [
    "~/Library/Preferences/com.doffice.app.plist",
    "~/Library/Application Support/Doffice",
  ]
end
