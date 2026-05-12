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
    nix-homebrew.url = "git+https://github.com/zhaofengli/nix-homebrew.git?ref=main&shallow=1";
    homebrew-core = {
      url = "git+https://github.com/homebrew/homebrew-core.git?shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "git+https://github.com/homebrew/homebrew-cask.git?shallow=1";
      flake = false;
    };
    # Third-party Homebrew tap used for some Chinese casks (e.g. easytier-gui)
    # Correct repository: https://github.com/Brewforge/homebrew-chinese
    brewforge-chinese = {
      url = "git+https://github.com/Brewforge/homebrew-chinese.git?shallow=1";
      flake = false;
    };
    # 第三方 Homebrew tap：tokentracker
    # - 提供 cask: mm7894215/tokentracker/tokentracker（AI token 用量采集/监控工具）
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
                # 将第三方 tap 映射给 nix-homebrew。映射 key 使用 Homebrew tap 名称（如 "mm7894215/tokentracker"），
                # value 为对应的 inputs 引用（上面定义的 mm7894215-tokentracker）。
                # 该映射用于在启用 darwin/gui 的主机上注册并管理这些 tap/cask。
                taps = {
                  # 映射 key 必须和 homebrew 实际使用的 tap 名称一致（owner/repo），例如：
                  # "homebrew/core"、"homebrew/cask"、"brewforge/chinese"、"mm7894215/tokentracker"。
                  # 使用正确的 owner/repo 名称可以让 nix-homebrew 在 /opt/homebrew/Library/Taps
                  # 下创建对应的只读路径，从而避免 Homebrew 在运行时尝试 `git clone`（在只读位置会触发 Permission denied）。
                  # 映射 key 必须为 GitHub 上的实际仓库路径 owner/repo（repo 为真实仓库名），
                  # 例如 homebrew 的 core 仓库为 homebrew/homebrew-core，brewforge 的仓库为 brewforge/homebrew-chinese。
                  # 这样 nix-homebrew 会在 /opt/homebrew/Library/Taps/<owner>/<repo> 下创建只读路径，
                  # 避免 Homebrew 在运行时尝试 `git clone`（在只读位置会触发 Permission denied）。
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "brewforge/homebrew-chinese" = brewforge-chinese;
                  "mm7894215/homebrew-tokentracker" = mm7894215-tokentracker;
                };
                # 保持 mutableTaps = false（只读映射）。历史上 brewforge-chinese 的问题是因为
                # 映射 key 使用了 "brewforge/homebrew-chinese"（不符合 Homebrew 的 owner/repo 命名），
                # 导致 Homebrew 在运行时尝试 `git clone` 到 /opt/homebrew/Library/Taps，从而触发 Permission denied。
                # 修复方法是把映射 key 改为 Homebrew 期望的 owner/repo（例如 "brewforge/chinese"），
                # 使 nix-homebrew 在 /opt/homebrew/Library/Taps 下提供对应的只读路径，而无需允许 Homebrew 直接写入。
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
