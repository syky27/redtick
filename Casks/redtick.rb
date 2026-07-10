cask "redtick" do
  version "1.12.0"
  sha256 "7afadead8334ca71ddaddf988f084b1665949181213dfd783c793832cb3f8375"

  url "https://github.com/syky27/redtick/releases/download/v#{version}/redtick-v#{version}.dmg"
  name "Redtick"
  desc "Redmine-native time tracker (Toggl Desktop experience for Redmine)"
  homepage "https://github.com/syky27/redtick"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: :catalina
  depends_on arch: :arm64

  app "Redtick.app"

  zap trash: [
    "~/Library/Application Support/cz.syky.redtick.redtick",
    "~/Library/Caches/cz.syky.redtick.redtick",
    "~/Library/HTTPStorages/cz.syky.redtick.redtick",
    "~/Library/Preferences/cz.syky.redtick.redtick.plist",
    "~/Library/Saved Application State/cz.syky.redtick.redtick.savedState",
  ]
end
