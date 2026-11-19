cask "rex" do
  version :latest
  sha256 :no_check

  url "https://blob.superlogical.com/download/rex-app/preview-arm64/latest.dmg"
  name "Rex"
  desc "Terminal with persistent sessions and programmable workspaces"
  homepage "https://www.superlogical.com/rex"

  auto_updates true
  depends_on arch: :arm64

  app "Rex.app"
  binary "#{appdir}/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex",
         target: "rex"
end
