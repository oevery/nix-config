{ pkgs, host, ... }:

{
  # 指定系统主用户：system.defaults 等用户相关设置将应用到该账户。
  system.primaryUser = host.username;

  # 启用系统层 zsh 管理（不影响 Home Manager 中的 zsh 配置）。
  programs.zsh.enable = true;

  # Nix 核心行为与垃圾回收策略。
  nix = {
    enable = true;
    settings = {
      # 启用 flakes 与新命令接口。
      experimental-features = "nix-command flakes";
      # 使用清华镜像并保留官方缓存，提高下载成功率。
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
      ];
      # 自动去重 /nix/store，节省磁盘空间。
      auto-optimise-store = true;
      # 保留构建输出与 derivation，便于调试和复用。
      keep-outputs = true;
      keep-derivations = true;
      # 允许构建器优先使用二进制缓存。
      builders-use-substitutes = true;
      # 允许 flake 内声明的额外配置生效。
      accept-flake-config = true;
      # 网络不稳定时更稳健。
      connect-timeout = 10;
      fallback = true;
      # 按机器能力自动并发构建。
      max-jobs = "auto";
      # 允许 root 与当前主用户管理 Nix。
      trusted-users = [
        "root"
        host.username
      ];
    };

    # 每周定时清理 7 天前的旧代。
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

  # 开启 sudo 的 Touch ID 验证。
  security.pam.services.sudo_local.touchIdAuth = true;

  # macOS 原生偏好设置（等价于 defaults write 的声明式管理）。
  system.defaults = {
    dock = {
      # 自动隐藏 Dock，减少屏幕占用。
      autohide = true;
      # 关闭最近使用空间排序，保持桌面空间顺序稳定。
      mru-spaces = false;
      # 不显示最近应用。
      show-recents = false;
    };

    finder = {
      # 总是显示文件扩展名。
      AppleShowAllExtensions = true;
      # 显示路径栏与状态栏，便于定位与统计。
      ShowPathbar = true;
      ShowStatusBar = true;
      # 默认列表视图。
      FXPreferredViewStyle = "Nlsv";
    };

    NSGlobalDomain = {
      # 关闭按住键弹出重音菜单，恢复按住连发行为。
      ApplePressAndHoldEnabled = false;
      # 更快的键盘重复速度。
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # 使用传统滚动方向（非自然滚动）。
      "com.apple.swipescrolldirection" = false;
    };

    trackpad = {
      # 允许轻点点击与三指拖拽。
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  # 系统层基础工具（与 Home Manager 用户层工具互补）。
  environment.systemPackages = with pkgs; [
    coreutils
    curl
  ];

  # 遇到 nix-darwin 重大变更时，再按发布说明更新该版本号。
  system.stateVersion = 6;
}
