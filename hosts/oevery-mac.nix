{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    homeConfigurationName = "oevery-mac";
    darwinName = "oevery-mac";
    enablePrivateGit = true;
    pinentryPackage = "pinentry_mac";
    modules = [
      "apps/hmops"
      "base/core"
      "darwin/core"
      # macOS 图形应用由 Homebrew 安装。
      "darwin/gui"
      "apps/mihomo"
    ];
  }
)
