{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    gpgKey = "87DD35546E137CA5";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
