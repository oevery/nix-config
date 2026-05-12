{
  description = "Home Manager configuration";

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "git+https://github.com/nix-darwin/nix-darwin.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "git+https://github.com/zhaofengli/nix-homebrew.git?ref=main&shallow=1";
    homebrew-core = {
      url = "git+https://github.com/homebrew/homebrew-core.git?shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "git+https://github.com/homebrew/homebrew-cask.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap（如 easytier-gui）
    brewforge-chinese = {
      url = "git+https://github.com/Brewforge/homebrew-chinese.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap：tokentracker
    mm7894215-tokentracker = {
      url = "git+https://github.com/mm7894215/homebrew-tokentracker.git?shallow=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      brewforge-chinese,
      mm7894215-tokentracker,
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
        let
          enableDarwinGui = builtins.elem "darwin/gui" settings.modules;
          isAppleSilicon = nixpkgs.lib.hasPrefix "aarch64-" settings.system;
        in
        nix-darwin.lib.darwinSystem {
          system = settings.system;
          specialArgs = {
            inherit inputs;
            inherit myLib;
            host = removeAttrs settings [ "system" ];
          };
          modules = [
            ./modules/darwin/core/system.nix
          ]
          ++ nixpkgs.lib.optionals enableDarwinGui [
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = isAppleSilicon;
                user = settings.username;
                autoMigrate = true;
                # key 用 GitHub 仓库路径，value 用对应 input。
                taps = {
                  # 例如 homebrew/homebrew-core、brewforge/homebrew-chinese。
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "brewforge/homebrew-chinese" = brewforge-chinese;
                  "mm7894215/homebrew-tokentracker" = mm7894215-tokentracker;
                };
                # 只读管理 taps，避免 Homebrew 运行时改写 Tap 目录。
                mutableTaps = false;
              };
            }
            (
              { ... }:
              {
                homebrew.taps = [
                  "homebrew/core"
                  "homebrew/cask"
                  "brewforge/chinese"
                  "mm7894215/tokentracker"
                ];
              }
            )
          ]
          ++ nixpkgs.lib.optionals enableDarwinGui [
            ./modules/darwin/gui/homebrew.nix
          ]
          ++ [
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
      darwinNames = nixpkgs.lib.mapAttrsToList (
        hostKey: settings:
        assert nixpkgs.lib.assertMsg (
          settings ? darwinName && builtins.isString settings.darwinName && settings.darwinName != ""
        ) "darwin host ${hostKey} must define a non-empty string darwinName.";
        settings.darwinName
      ) darwinHosts;
      _darwinNameUnique =
        assert nixpkgs.lib.assertMsg (
          builtins.length darwinNames == builtins.length (nixpkgs.lib.unique darwinNames)
        ) "darwinName must be unique across all darwin hosts.";
        true;
      darwinConfigurations = nixpkgs.lib.mapAttrs' (
        hostKey: settings:
        assert _darwinNameUnique;
        {
          name = settings.darwinName;
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
              (hostKey: {
                name = "darwin-${darwinHosts.${hostKey}.darwinName}";
                value = darwinConfigurations.${darwinHosts.${hostKey}.darwinName}.config.system.build.toplevel;
              })
              (builtins.attrNames (nixpkgs.lib.filterAttrs (_: settings: settings.system == system) darwinHosts))
          );
        in
        homeChecks // darwinChecks
      );
    };
}
