{ ... }:

{
  # macOS 桌面偏好设置。
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0; # 鼠标移到边缘时立即显示 Dock，不额外取消展开动画。
      mru-spaces = false; # 不按最近使用情况自动重排桌面空间。
      expose-group-apps = false; # 调度中心分别展示窗口，不按应用分组。
      minimize-to-application = true; # 最小化窗口收入所属应用图标，不在 Dock 中单独占位。
      show-recents = false; # 隐藏 Dock 的最近使用应用区域，保留固定应用。
      # 与下方四指手势配合：上滑调度中心、下滑 App Exposé。
      showMissionControlGestureEnabled = true;
      showAppExposeGestureEnabled = true;
      showDesktopGestureEnabled = true; # 张开拇指和其他三指显示桌面。
      showLaunchpadGestureEnabled = true; # 捏拢拇指和其他三指。
    };

    WindowManager = {
      EnableTiledWindowMargins = false; # 系统平铺窗口时不留边距，不影响调度中心。
    };

    finder = {
      AppleShowAllFiles = true; # 显示隐藏文件，方便访问 .gitignore、.env 等配置。
      ShowPathbar = true; # 窗口底部显示当前目录路径。
      ShowStatusBar = true; # 窗口底部显示项目数量、可用空间等状态。
      FXPreferredViewStyle = "Nlsv"; # Nlsv = 列表视图。
      FXDefaultSearchScope = "SCcf"; # SCcf = 默认搜索当前文件夹。
      # 按名称排序时，Finder 窗口和桌面均将文件夹排在文件前面。
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
    };

    # 全局默认偏好；应用自己的设置可能覆盖它们，并非所有编辑器都会遵循。
    NSGlobalDomain = {
      AppleShowAllExtensions = true; # 显示文件扩展名，与显示隐藏文件是两个独立设置。
      AppleICUForce24HourTime = true; # 使用 24 小时制。
      ApplePressAndHoldEnabled = false; # 长按按键重复输入，而非弹出重音字符菜单。
      # 保留输入的直引号和连字符，避免技术文本被自动替换。
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      # 两个保存面板偏好均设为展开，方便直接选择目录。
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      # 新文档默认保存到本机，不关闭 iCloud 同步；应用仍可能记住上次保存位置。
      NSDocumentSaveNewDocumentsToCloud = false;
      InitialKeyRepeat = 15; # 长按后开始重复输入的等待时间；越小越快。
      KeyRepeat = 2; # 开始重复后的输入间隔；越小越快。
      # 自然滚动。
      "com.apple.swipescrolldirection" = true;
      AppleEnableSwipeNavigateWithScrolls = true; # 双指左右滚动切换页面。
      "com.apple.trackpad.forceClick" = true; # 配合触控板设置启用单指用力点按。
    };

    CustomUserPreferences = {
      # 避免在网络和 USB 磁盘生成 Finder 目录显示设置文件；不清理已有 .DS_Store。
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      # 将 ⌘Space 留给 Tinycast，保留 Finder 搜索快捷键。
      # parameters 依次为字符码、虚拟键码、修饰键掩码。
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "160" = {
            enabled = 0;
          };
          "64" = { # 显示 Spotlight 搜索。
            enabled = 0;
            value = {
              parameters = [ 32 49 1048576 ]; # ⌘Space
              type = "standard";
            };
          };
          "65" = { # 打开 Finder 搜索窗口。
            enabled = 1;
            value = {
              parameters = [ 32 49 1572864 ]; # ⌥⌘Space
              type = "standard";
            };
          };
        };
      };

      # 仅控制菜单栏时钟，不改变通知中心的日期和日历显示。
      "com.apple.menuextra.clock" = {
        IsAnalog = 0; # 0=数字时钟, 1=模拟时钟
        ShowAMPM = 0; # 0=不显示 AM/PM, 1=显示 AM/PM
        ShowDate = 2; # 0=空间允许时显示, 1=始终显示, 2=不显示日期
        ShowDayOfMonth = 0; # 不显示月份中的日期数字，仅保留时间。
        ShowDayOfWeek = 0; # 0=不显示星期, 1=显示星期
        FlashDateSeparators = 0; # 0=分隔符不闪烁, 1=分隔符闪烁
      };
    };

    # nix-darwin 将这些选项同时写入内置和蓝牙触控板偏好。
    trackpad = {
      Clicking = true; # 轻点触控板即可点击，无需按下。
      TrackpadRightClick = true; # 辅助点按：双指点按或轻点。
      TrackpadCornerSecondaryClick = 0; # 不使用左下角或右下角作为辅助点按。

      # 系统界面的“用力点按与触感反馈”作为一组开启，不改变点按力度。
      ForceSuppressed = false;
      ActuateDetents = true;
      TrackpadThreeFingerTapGesture = 0; # 查询采用单指用力点按，不使用三指轻点；并非关闭查询。

      # 滚动与缩放：自然滚动在 NSGlobalDomain 中配置。
      TrackpadPinch = true; # 双指捏合缩放。
      TrackpadTwoFingerDoubleTapGesture = true; # 双指轻点两下进行智能缩放。
      TrackpadRotate = true; # 双指旋转。
      TrackpadMomentumScroll = true; # 松开手指后滚动逐渐停止。

      # 更多手势：双指翻页，四指切换应用、调度中心和 App Exposé。
      TrackpadThreeFingerHorizSwipeGesture = 0; # 不用三指切换页面或全屏应用。
      TrackpadFourFingerHorizSwipeGesture = 2; # 四指左右轻扫切换全屏应用。
      TrackpadThreeFingerVertSwipeGesture = 0; # 垂直切换使用四指，并非关闭调度中心。
      TrackpadFourFingerVertSwipeGesture = 2; # 四指上滑调度中心、下滑 App Exposé；以实际系统界面为准。
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3; # 双指从右边缘向左轻扫打开通知中心。
      TrackpadFourFingerPinchGesture = 2; # 启用拇指与其他三指的捏拢/张开，配合 Dock 中的开关。

      # 无障碍 → 指针控制 → 触控板选项：选择三指拖移，而非轻点拖移。
      TrackpadThreeFingerDrag = true; # 使用三指拖移窗口或项目。
      Dragging = false;
      DragLock = false;
    };
  };
}
