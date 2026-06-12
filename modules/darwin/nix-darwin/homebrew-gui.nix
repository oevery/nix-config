{ ... }:

{
  # macOS 下通过 Homebrew 管理的 GUI 和 App Store 应用。
  homebrew = {
    # 第三方 cask 需先在 flake.nix 中注册对应 tap。
    casks = [
      # 终端与开发。
      # "iterm2" # 终端。
      "visual-studio-code" # 编辑器。
      "hbuilderx" # uni-app 开发 IDE。
      "wechatwebdevtools" # 微信开发者工具（小程序/公众号）。
      "reqable" # API 调试与代理抓包。
      "iloader" # 用户友好的 iOS sideloader
      "dbeaver-community" # 数据库管理与 SQL 客户端。
      "android-studio" # Android 开发与模拟器。
      # AI / 监控。
      "codex-app" # OpenAI Codex 桌面编码代理。
      # "lm-studio" # 本地 LLM 下载、管理与推理桌面应用。
      "mm7894215/tokentracker/tokentracker" # AI token 用量监控。
      # 如遇“已损坏，无法打开”，见 docs/quarantine.md。

      # 效率工具。
      "raycast" # 快捷启动。
      "stats" # 系统监控。
      "thaw" # 菜单栏管理工具。
      "mos" # 鼠标滚动增强。
      "alt-tab" # 窗口切换。
      # "rectangle" # 窗口管理。
      "pixpin" # 截图与标注。
      "keka" # 压缩/解压 GUI 工具。
      "localsend" # 局域网跨设备文件传输。
      "monitorcontrol" # 外接显示器亮度/音量控制。

      # 浏览器。
      "google-chrome"
      "firefox"

      # 密码管理。
      "bitwarden"

      # 通讯协作。
      "wechat"
      "qq"
      "tencent-meeting" # 腾讯会议。
      "feishu" # 飞书。
      "lark" # Lark 国际版。
      "telegram"
      "readdle-spark" # Spark 邮件客户端。
      "termius" # SSH 客户端。

      # 远程。
      "uuremote" # 网易 UU 远程桌面。
      "windows-app" # 微软远程桌面。
      "utm" # 虚拟机与系统模拟工具。
      # "rustdesk" # 开源远程桌面。
      "brewforge/chinese/easytier-gui" # EasyTier 桌面 GUI。
      # 如遇“已损坏，无法打开”，见 docs/quarantine.md。

      # 媒体娱乐。
      "neteasemusic" # 网易云音乐。
      "obs" # 直播与录屏。
      "upscayl" # AI 图片放大工具。
      "iina" # 本地媒体播放器。

      # 办公软件。
      "wpsoffice" # 金山 WPS Office。
      "onedrive" # OneDrive 文件同步客户端。

      # 知识管理。
      "obsidian" # 本地 Markdown 知识库。
    ];

    # 更适合通过 App Store 安装的应用。
    masApps = {
      "Xcode" = 497799835;
      # "Numbers" = 409203825;
      # "Keynote" = 409183694;
      # "Pages" = 409201541;
      # "GarageBand" = 682658836;
      # "iMovie" = 408981434;
    };
  };
}
