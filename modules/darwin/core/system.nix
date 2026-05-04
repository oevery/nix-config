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
      # 同时声明 Apple Silicon 与 Intel Darwin 平台，提升缓存命中率。
      extra-platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # 使用交大二进制缓存（包含 darwin 二进制包），并保留官方缓存作为回退。
      substituters = [
        "https://mirror.sjtu.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
      ];
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

    # 使用官方推荐选项自动优化 /nix/store，避免旧选项断言失败。
    optimise.automatic = true;

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

      # 仅保留指定应用。
      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Applications/System Settings.app"
        "/Applications/Google Chrome.app"
        "/Applications/Visual Studio Code.app"
      ];

      # Dock 右侧保留 Developer 文件夹。
      persistent-others = [
        "/Users/${host.username}/Developer"
      ];
    };

    finder = {
      # 显示路径栏与状态栏，便于定位与统计。
      ShowPathbar = true;
      ShowStatusBar = true;
      # 默认列表视图。
      FXPreferredViewStyle = "Nlsv";
      # 默认排序相关：按名称排序时文件夹置顶（窗口与桌面）。
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
    };

    NSGlobalDomain = {
      # 总是显示文件扩展名（全局域键，放这里才稳定生效）。
      AppleShowAllExtensions = true;
      # 启用 24 小时制时间显示。
      AppleICUForce24HourTime = true;
      # 关闭按住键弹出重音菜单，恢复按住连发行为。
      ApplePressAndHoldEnabled = false;
      # 更快的键盘重复速度。
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # 使用自然滚动
      "com.apple.swipescrolldirection" = true;
    };

    # 自定义 macOS 偏好项（defaults 域）。
    CustomUserPreferences = {
      # Finder：不在网络磁盘上创建 .DS_Store。
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
      };

      # 关闭系统 Spotlight 快捷键（Cmd+Space / Option+Cmd+Space），避免与 Raycast 冲突。
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # 系统设置 > 键盘快捷键 > Spotlight：显示 App
          "160" = {
            enabled = 0;
          };
          # 系统设置 > 键盘快捷键 > Spotlight：显示“聚焦”搜索（Cmd+Space）
          "64" = {
            enabled = 0;
          };
          # 系统设置 > 键盘快捷键 > Spotlight：显示“访达”搜索窗口（Option+Cmd+Space）
          "65" = {
            enabled = 0;
          };
        };
      };

      # 菜单栏时钟。
      "com.apple.menuextra.clock" = {
        IsAnalog = 0; # 0=数字时钟, 1=模拟时钟
        ShowAMPM = 0; # 0=不显示 AM/PM, 1=显示 AM/PM
        ShowDate = 0; # 0=不显示日期, 1=空间允许时显示, 2=始终显示
        ShowDayOfWeek = 0; # 0=不显示星期, 1=显示星期
        FlashDateSeparators = 0; # 0=分隔符不闪烁, 1=分隔符闪烁
      };
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
