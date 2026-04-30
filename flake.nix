{
  description = "Home Manager configuration";

  inputs = {
    # 指定 Home Manager 与 Nixpkgs 的来源。
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # 源码获取走 GitHub，避免镜像 git 仓库排队
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "git+https://github.com/nix-darwin/nix-darwin.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }@inputs:
    let
      myLib = import ./lib { lib = nixpkgs.lib; };
      hosts = import ./hosts { inherit myLib; };
      systems = nixpkgs.lib.unique (map (settings: settings.system) (builtins.attrValues hosts));
      resolveHostModules = modules: map (name: myLib.moduleRegistry.${name}) modules;

      mkHome =
        settings:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${settings.system};
          extraSpecialArgs = {
            inherit inputs;
            inherit myLib;
            host = removeAttrs settings [ "system" ];
          };
          modules = [
            ./home.nix
          ]
          ++ resolveHostModules settings.modules;
        };

      mkDarwin =
        settings:
        nix-darwin.lib.darwinSystem {
          system = settings.system;
          specialArgs = {
            inherit inputs;
            inherit myLib;
            host = removeAttrs settings [ "system" ];
          };
          modules = [
            ./modules/darwin/core/system.nix
            home-manager.darwinModules.home-manager
            {
              users.users.${settings.username}.home = "/Users/${settings.username}";

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  inherit myLib;
                  host = removeAttrs settings [ "system" ];
                };
                users.${settings.username} = {
                  imports = [
                    ./home.nix
                  ]
                  ++ resolveHostModules settings.modules;
                };
              };
            }
          ];
        };

      homeConfigurations = nixpkgs.lib.mapAttrs (_: settings: mkHome settings) hosts;
      darwinHosts = nixpkgs.lib.filterAttrs (
        _: settings: settings.system == "aarch64-darwin" || settings.system == "x86_64-darwin"
      ) hosts;
      darwinConfigurations = nixpkgs.lib.mapAttrs' (
        hostKey: settings:
        let
          hostName = builtins.elemAt (nixpkgs.lib.splitString "@" hostKey) 1;
        in
        {
          name = hostName;
          value = mkDarwin settings;
        }
      ) darwinHosts;
    in
    {
      inherit homeConfigurations;
      inherit darwinConfigurations;
      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          hostKeys = builtins.attrNames (
            nixpkgs.lib.filterAttrs (_: settings: settings.system == system) hosts
          );
          homeChecks = builtins.listToAttrs (
            map (hostKey: {
              name = "home-${builtins.replaceStrings [ "@" ] [ "-" ] hostKey}";
              value = homeConfigurations.${hostKey}.activationPackage;
            }) hostKeys
          );
          darwinChecks = builtins.listToAttrs (
            map
              (
                hostKey:
                let
                  hostName = builtins.elemAt (nixpkgs.lib.splitString "@" hostKey) 1;
                in
                {
                  name = "darwin-${hostName}";
                  value = darwinConfigurations.${hostName}.system.build.toplevel;
                }
              )
              (builtins.attrNames (nixpkgs.lib.filterAttrs (_: settings: settings.system == system) darwinHosts))
          );
        in
        homeChecks // darwinChecks
      );
    };
}
