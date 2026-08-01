{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05&shallow=1";
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=release-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "git+https://github.com/nix-darwin/nix-darwin.git?ref=nix-darwin-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 显式锁定 Homebrew 执行引擎，避免新 tap DSL 超前于 nix-homebrew 的内置版本。
    brew-src = {
      url = "github:Homebrew/brew/6.0.13";
      flake = false;
    };
    nix-homebrew = {
      url = "git+https://github.com/zhaofengli/nix-homebrew.git?ref=main&shallow=1";
      inputs.brew-src.follows = "brew-src";
    };
    homebrew-core = {
      url = "git+https://github.com/homebrew/homebrew-core.git?shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "git+https://github.com/homebrew/homebrew-cask.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap（例如 easytier-gui）。
    brewforge-chinese = {
      url = "git+https://github.com/Brewforge/homebrew-chinese.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap：tokentracker。
    mm7894215-tokentracker = {
      url = "git+https://github.com/mm7894215/homebrew-tokentracker.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap：omlx。
    jundot-omlx = {
      url = "git+https://github.com/jundot/omlx.git?shallow=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      brew-src,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      brewforge-chinese,
      mm7894215-tokentracker,
      jundot-omlx,
      ...
    }@inputs:
    let
      myLib = import ./lib { lib = nixpkgs.lib; };
      hosts = import ./hosts { inherit myLib; };
      systems = hostSystems hosts;
      resolveHostModules = modules: map (name: myLib.moduleRegistry.${name}) modules;
      makeSpecialArgs = settings: {
        inherit inputs myLib;
        host = removeAttrs settings [ "system" ];
      };
      darwinHosts = nixpkgs.lib.filterAttrs (
        _: settings: settings.system == "aarch64-darwin" || settings.system == "x86_64-darwin"
      ) hosts;
      hostSystems =
        hostSet: nixpkgs.lib.unique (map (settings: settings.system) (builtins.attrValues hostSet));
      darwinSystems = hostSystems darwinHosts;
      uniqueAttr =
        attrName: hostSet:
        let
          values = map (settings: settings.${attrName}) (builtins.attrValues hostSet);
        in
        assert nixpkgs.lib.assertMsg (
          builtins.all (name: builtins.isString name && name != "") values
          && builtins.length values == builtins.length (nixpkgs.lib.unique values)
        ) "${attrName} must be a non-empty unique string across all hosts.";
        true;
      renderNamedOutputs =
        attrName: hostSet: transform:
        let
          _ = uniqueAttr attrName hostSet;
        in
        nixpkgs.lib.mapAttrs' (_hostKey: settings: {
          name = settings.${attrName};
          value = transform settings;
        }) hostSet;

      darwinTaps = {
        "homebrew/homebrew-core" = homebrew-core;
        "homebrew/homebrew-cask" = homebrew-cask;
        "brewforge/homebrew-chinese" = brewforge-chinese;
        "mm7894215/homebrew-tokentracker" = mm7894215-tokentracker;
        "jundot/homebrew-omlx" = jundot-omlx;
      };

      darwinTapNames = [
        "homebrew/core"
        "homebrew/cask"
        "brewforge/chinese"
        "mm7894215/tokentracker"
        "jundot/omlx"
        "oevery/local"
      ];

      mkHostModules = settings: [ ./home.nix ] ++ resolveHostModules settings.modules;

      mkHome =
        settings:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${settings.system};
          extraSpecialArgs = makeSpecialArgs settings;
          modules = mkHostModules settings;
        };

      mkDarwin =
        settings:
        let
          enableDarwinGuiModules = builtins.elem "darwin/gui" settings.modules;
          isAppleSilicon = nixpkgs.lib.hasPrefix "aarch64-" settings.system;
          pkgs = nixpkgs.legacyPackages.${settings.system};
          localHomebrewTap = pkgs.stdenvNoCC.mkDerivation {
            pname = "homebrew-local";
            version = "1";
            src = ./homebrew/local;
            installPhase = ''
              mkdir -p "$out"
              cp -R . "$out"
            '';
          };
        in
        nix-darwin.lib.darwinSystem {
          system = settings.system;
          specialArgs = makeSpecialArgs settings;
          modules = [
            ./modules/darwin/nix-darwin/core.nix
            ./modules/darwin/nix-darwin/kilo-cleaner.nix
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                package = brew-src // {
                  name = "brew-6.0.13";
                  version = "6.0.13";
                };
                enableRosetta = isAppleSilicon;
                user = settings.username;
                autoMigrate = true;
                taps = darwinTaps // {
                  "oevery/homebrew-local" = localHomebrewTap;
                };
                trust.casks = [
                  "oevery/local/ishell-pro"
                  "oevery/local/oppo-connect"
                ];
                # 只读管理 taps，避免 Homebrew 运行时改写 Tap 目录。
                mutableTaps = false;
              };
            }
            (
              { ... }:
              {
                homebrew.taps = darwinTapNames;
              }
            )
            ./modules/darwin/nix-darwin/homebrew.nix
          ]
          ++ nixpkgs.lib.optionals enableDarwinGuiModules [
            ./modules/darwin/nix-darwin/desktop.nix
            ./modules/darwin/nix-darwin/homebrew-gui.nix
          ]
          ++ [
            home-manager.darwinModules.home-manager
            {
              users.users.${settings.username}.home = "/Users/${settings.username}";

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = makeSpecialArgs settings;
                users.${settings.username} = {
                  imports = mkHostModules settings;
                };
              };
            }
          ];
        };

      homeConfigurations = renderNamedOutputs "homeConfigurationName" hosts mkHome;
      darwinConfigurations = renderNamedOutputs "darwinName" darwinHosts mkDarwin;
    in
    {
      inherit homeConfigurations;
      inherit darwinConfigurations;
      apps = nixpkgs.lib.genAttrs darwinSystems (system: {
        darwin-rebuild = {
          type = "app";
          program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
          meta = {
            description = "Run nix-darwin darwin-rebuild from this flake's nix-darwin input";
          };
        };
      });
      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          systemHomeHosts = nixpkgs.lib.filterAttrs (_: settings: settings.system == system) hosts;
          systemDarwinHosts = nixpkgs.lib.filterAttrs (_: settings: settings.system == system) darwinHosts;
          homeChecks = nixpkgs.lib.mapAttrs' (_hostKey: settings: {
            name = "home-${settings.homeConfigurationName}";
            value = homeConfigurations.${settings.homeConfigurationName}.activationPackage;
          }) systemHomeHosts;
          darwinChecks = nixpkgs.lib.mapAttrs' (_hostKey: settings: {
            name = "darwin-${settings.darwinName}";
            value = darwinConfigurations.${settings.darwinName}.config.system.build.toplevel;
          }) systemDarwinHosts;
        in
        homeChecks // darwinChecks
      );
    };
}
