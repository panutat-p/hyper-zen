cask "hyperzen" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/panutat-p/hyper-zen/releases/download/v#{version}/Hyperzen.dmg"
  name "Hyperzen"
  desc "Lightweight macOS menu bar app that keeps your Mac awake"
  homepage "https://github.com/panutat-p/hyper-zen"

  depends_on macos: ">= :ventura"

  app "Hyperzen.app"

  zap trash: [
    "~/Library/Preferences/com.hyperzen.Hyperzen.plist",
    "~/Library/Application Support/Hyperzen",
    "~/Library/Caches/com.hyperzen.Hyperzen",
  ]
end
