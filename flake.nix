{
  description = "Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # use Tsinghua University mirror for better speed in China
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      commonSettings = {
        username = "oevery";
        email = "i@oevery.me";
        gitName = "oevery";
        system = "x86_64-linux";
      };

      mkHome =
        { settings }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${settings.system};
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home.nix
            { myOpts = removeAttrs settings [ "system" ]; }
          ];
        };
    in
    {
      homeConfigurations = {
        "oevery@homelab" = mkHome {
          settings = commonSettings // {
            gpgKey = "87DD35546E137CA5";
          };
        };

        "oevery@oevery-desktop" = mkHome {
          settings = commonSettings // {
            gpgKey = "8A57E8A748ACB570";
          };
        };
      };
    };
}
