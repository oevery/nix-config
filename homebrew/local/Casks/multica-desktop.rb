cask "multica-desktop" do
  version "0.11.0"
  sha256 "3d44184f1cc5194992547a43ff4a8f70c50f6c58772eb3d39cfaeb4020d84986"

  url "https://github.com/multica-ai/multica/releases/download/v#{version}/multica-desktop-#{version}-mac-arm64.dmg"
  name "Multica"
  desc "Desktop client for the Multica agent workspace"
  homepage "https://multica.ai/"

  auto_updates true
  depends_on arch: :arm64, macos: :ventura

  app "Multica.app"
end
