{ host, ... }:

{
  # macOS 桌面偏好设置。
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;

      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Applications/System Settings.app"
        "/Applications/Google Chrome.app"
        "/Applications/Visual Studio Code.app"
      ];

      persistent-others = [
        "/Users/${host.username}/Developer"
      ];
    };

    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";
      # 文件夹置顶。
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleICUForce24HourTime = true;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # 自然滚动。
      "com.apple.swipescrolldirection" = true;
    };

    CustomUserPreferences = {
      # 网络磁盘不写 .DS_Store。
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
      };

      # 关闭 Spotlight 快捷键，避免与 Raycast 冲突。
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "160" = {
            enabled = 0;
          };
          "64" = {
            enabled = 0;
          };
          "65" = {
            enabled = 0;
          };
        };
      };

      "com.apple.menuextra.clock" = {
        IsAnalog = 0; # 0=数字时钟, 1=模拟时钟
        ShowAMPM = 0; # 0=不显示 AM/PM, 1=显示 AM/PM
        ShowDate = 0; # 0=不显示日期, 1=空间允许时显示, 2=始终显示
        ShowDayOfWeek = 0; # 0=不显示星期, 1=显示星期
        FlashDateSeparators = 0; # 0=分隔符不闪烁, 1=分隔符闪烁
      };
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };
}
