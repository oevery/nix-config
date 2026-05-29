{ pkgs, host, ... }:

{
  # 系统主用户。
  system.primaryUser = host.username;

  # 启用系统层 zsh。
  programs.zsh.enable = true;

  nix = {
    enable = true;
    settings = {
      experimental-features = "nix-command flakes";
      # 提升 Darwin 二进制缓存命中率。
      extra-platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      substituters = [
        # "https://mirror.sjtu.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
      ];
      keep-outputs = true;
      keep-derivations = true;
      builders-use-substitutes = true;
      accept-flake-config = true;
      connect-timeout = 10;
      fallback = true;
      max-jobs = "auto";
      trusted-users = [
        "root"
        host.username
      ];
    };

    optimise.automatic = true;

    # 每周清理 7 天前旧代。
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
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
