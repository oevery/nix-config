{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    darwinName = "oevery-mac";
    gpgKey = "FF2F947EF8595DC8";
    modules = [
      "base/core"
      # 如需改为 Nix 管理 GUI，可启用 base/gui。
      # "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
