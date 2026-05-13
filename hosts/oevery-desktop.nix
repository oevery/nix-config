{ mkHost, common }:

mkHost (
  common
  // {
    system = "x86_64-linux";
    homeConfigurationName = "oevery-desktop";
    gpgKey = "8A57E8A748ACB570";
    modules = [
      "base/core"
      "linux/core"
    ];
  }
)
