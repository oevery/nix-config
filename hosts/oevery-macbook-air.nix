{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    gpgKey = null;
    modules = [
      "base/core"
      "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
