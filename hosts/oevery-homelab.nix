{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-homelab";
    gpgKey = "87DD35546E137CA5";
    pinentryPackage = "pinentry-curses";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
