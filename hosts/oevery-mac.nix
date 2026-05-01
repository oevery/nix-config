{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    darwinName = "oevery-mac";
    gpgKey = null;
    modules = [
      "base/core"
      "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
