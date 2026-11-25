{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    homeConfigurationName = "oevery-mac";
    darwinName = "oevery-mac";
    enableMihomo = true;
    enablePrivateGit = true;
    pinentryPackage = "pinentry_mac";
    modules = [
      "base/core"
      # 如需改为 Nix 管理 GUI，可启用 base/gui。
      # "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
