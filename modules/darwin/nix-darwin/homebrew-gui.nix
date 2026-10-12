{ ... }:

{
  # macOS 下通过 Homebrew 管理的 GUI 和 App Store 应用。
  homebrew = {
    # 第三方 cask 需先在 flake.nix 中注册对应 tap。
    casks = [
      # 终端与开发。
      "warp" # Warp 终端。
      "dbx" # 轻量级数据库客户端。
      "visual-studio-code" # 编辑器。
      "zed" # 编辑器。
      "hbuilderx" # uni-app 开发 IDE。
      "wechatwebdevtools" # 微信开发者工具（小程序/公众号）。
      "reqable" # API 调试与代理抓包。
      "iloader" # 用户友好的 iOS sideloader
      "android-studio" # Android 开发与模拟器。
      "orbstack" # Docker/容器运行时。
      # AI / 监控。
      # "codex" # OpenAI Codex 桌面编码代理。
      "chatgpt" # OpenAI ChatGPT 桌面应用。

      # 效率工具。
      {
        name = "vishvavariya/notchy/notchy";
        greedy = true; # 自带更新功能的 cask 也由 drs 纳入升级。
        trusted = true; # 仅信任当前使用的 Notchy cask。
      }
      "mos" # 鼠标滚动增强。
      "pixpin" # 截图与标注。
      "keka" # 压缩/解压 GUI 工具。
      "localsend" # 局域网跨设备文件传输。
      "monitorcontrol" # 外接显示器亮度/音量控制。

      # 浏览器。
      "google-chrome"
      "firefox"
      "115browser" # 115 浏览器/云盘。

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

      # 远程。
      "uuremote" # 网易 UU 远程桌面。
      "windows-app" # 微软远程桌面。
      {
        name = "oevery/local/ishell-pro";
        greedy = true; # version :latest 的自建 cask 需要 greedy 才会在 drs 时重新拉取。
      }
      {
        name = "brewforge/chinese/easytier-gui";
        trusted = true; # 仅信任当前使用的 EasyTier cask，不扩大到整个 Brewforge tap。
      }
      # 如遇“已损坏，无法打开”，见 docs/quarantine.md。

      # 媒体娱乐。
      "neteasemusic" # 网易云音乐。
      "obs" # 直播与录屏。
      "upscayl" # AI 图片放大工具。
      "iina" # 本地媒体播放器。

      # 办公软件。
      "libreoffice" # LibreOffice 办公套件。
      "wpsoffice" # 金山 WPS Office。
      "syncthing-app" # Syncthing 文件同步客户端。
      "onedrive" # OneDrive 文件同步客户端。

      # 知识管理。
      "obsidian" # 本地 Markdown 知识库。
    ];

    # 更适合通过 App Store 安装的应用。
    masApps = {
      "Xcode" = 497799835;
      "AndroMeld" = 6762439757; # Android 手机伴侣。
    };
  };
}
