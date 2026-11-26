{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-homelab";
    enablePrivateGit = true;
    pinentryPackage = "pinentry-curses";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
