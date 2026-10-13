cask "boring-notch-rc" do
  # 临时固定候选版；官方 tap 发布 2.8 稳定版后切回官方 cask。
  version "2.8-rc.2"
  sha256 "ea891b26642dcb766340716feb80df601f5fde7a154c5907d5f93a3695df110d"

  url "https://github.com/TheBoredTeam/boring.notch/releases/download/v#{version}/boringNotch.dmg"
  name "Boring Notch"
  desc "Not so boring notch That Rocks"
  homepage "https://github.com/TheBoredTeam/boring.notch"

  livecheck do
    skip "Pinned release candidate"
  end

  conflicts_with cask: "theboredteam/boring-notch/boring-notch"
  auto_updates true
  depends_on macos: :sonoma

  app "Boring Notch.app"

  postflight_steps do
    if_path_exists "{{appdir}}/Boring Notch.app" do
      run "/usr/bin/xattr",
          args: ["-dr", "com.apple.quarantine", "{{appdir}}/Boring Notch.app"]
    end
  end

  uninstall quit: "theboringteam.boringnotch"

  zap trash: [
    "~/Library/Application Scripts/theboringteam.boringnotch/",
    "~/Library/Containers/TheBoringNotch/",
    "~/Library/Containers/theboringteam.boringnotch/",
  ]
end
