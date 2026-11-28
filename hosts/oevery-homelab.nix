{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-homelab";
    enablePrivateGit = true;
    pinentryPackage = "pinentry-curses";
    modules = [
      "apps/hmops"
      "apps/mihomo"
      "base/core"
      "linux/core"
      "apps/omp"
      "apps/multica"
      "apps/magpie"
    ];
  }
)
