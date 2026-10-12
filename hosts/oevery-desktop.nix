{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-desktop";
    gpgKey = "8A57E8A748ACB570";
    pinentryPackage = "pinentry-gnome3";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
