{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-desktop";
    pinentryPackage = "pinentry-gnome3";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
