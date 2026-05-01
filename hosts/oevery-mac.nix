{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    darwinName = "oevery-mac";
    gpgKey = "FF2F947EF8595DC8";
    modules = [
      "base/core"
      "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
