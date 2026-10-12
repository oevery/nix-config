{
  config,
  lib,
  pkgs,
  host,
  ...
}:

{
  # 系统主用户。
  system.primaryUser = host.username;

  # 启用系统层 zsh。
  programs.zsh.enable = true;

  nix = {
    enable = true;
    settings = {
      experimental-features = "nix-command flakes";
      # 原生架构无需重复声明；启用 Rosetta 时允许本机构建 Intel 派生。
      extra-platforms = lib.optionals config.nix-homebrew.enableRosetta [ "x86_64-darwin" ];
      substituters = [
        # "https://mirror.sjtu.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
      ];
      keep-outputs = false;
      keep-derivations = true;
      builders-use-substitutes = true;
      accept-flake-config = true;
      connect-timeout = 10;
      fallback = true;
      max-jobs = "auto";
      # 保留 nix-darwin 默认的 root 信任；普通用户通过 allowed-users 访问 daemon。
    };

    optimise.automatic = true;

    # 每周清理 30 天前旧代，保留近期回滚窗口。
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 15;
      };
    };
  };

  # sudo 支持 Touch ID。
  security.pam.services.sudo_local.touchIdAuth = true;

  environment.systemPackages = with pkgs; [
    coreutils
    curl
  ];

  # 仅在 nix-darwin 发布说明要求时更新。
  system.stateVersion = 6;
}
