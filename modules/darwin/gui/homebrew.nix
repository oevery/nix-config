{ lib, ... }:

{
  # macOS 下的 Homebrew GUI/App Store 应用。
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    # 少量 macOS 专用 CLI。
    brews = [
      "mas"
      "mole" # Mac 清理与优化工具（CLI）
      "ios-deploy" # iOS 真机安装与调试（避免 Nix 在 macOS 上的私有框架构建限制）
      # "mm7894215/tokentracker/tokentracker" # AI token 用量采集 CLI
      # 在 macOS 上使用 Colima 作为容器运行时
      "colima" # 在 macOS 上运行容器的轻量方案（基于 lima）
      "docker" # Docker CLI（客户端）
      "docker-compose" # Docker Compose
    ];

    # 第三方 cask 需先在 flake.nix 中注册对应 tap。
    casks = [
      # 终端与开发
      # "iterm2" # 终端
      "visual-studio-code" # 编辑器
      "hbuilderx" # uni-app 开发 IDE
      "wechatwebdevtools" # 微信开发者工具（小程序/公众号）
      "reqable" # API 调试与代理抓包
      "dbeaver-community" # 数据库管理与 SQL 客户端
      "android-studio" # Android 开发与模拟器
      # AI / 监控
      "mm7894215/tokentracker/tokentracker" # AI token 用量监控
      # 如遇“已损坏，无法打开”，见 docs/quarantine.md。

      # 效率工具
      "raycast" # 快捷启动
      "stats" # 系统监控
      # "mos" # 鼠标滚动平滑与方向增强
      "alt-tab" # 窗口切换
      # "rectangle" # 窗口管理
      "pixpin" # 截图与标注
      "keka" # 压缩/解压 GUI 工具（Keka）

      # 浏览器
      "google-chrome"
      "firefox"

      # 密码管理
      "bitwarden"

      # 通讯协作
      "wechat"
      "qq"
      "telegram"
      "readdle-spark" # Spark 邮件客户端
      "termius" # SSH 客户端

      # 远程
      "uuremote" # 网易 UU 远程桌面
      "windows-app" # 微软远程桌面
      # "rustdesk" # 开源远程桌面
      "brewforge/chinese/easytier-gui" # EasyTier 桌面 GUI
      # 如遇“已损坏，无法打开”，见 docs/quarantine.md。

      # 媒体娱乐
      "neteasemusic" # 网易云音乐
      # "obs" # 直播与录屏
      # "iina" # 本地媒体播放器

      # 办公软件
      "wpsoffice" # 金山 WPS Office
      "onlyoffice" # OnlyOffice 本地办公套件，兼容 Microsoft Office 格式

      # 知识管理
      # "obsidian" # 本地 Markdown 知识库
    ];

    # 更适合走 App Store 的应用。
    masApps = {
      # "Xcode" = 497799835;
      # "Numbers" = 409203825;
      # "Keynote" = 409183694;
      # "Pages" = 409201541;
      # "GarageBand" = 682658836;
      # "iMovie" = 408981434;
    };
  };

  home.activation.ensureDockerComposePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v brew >/dev/null 2>&1; then
      compose_prefix="$(brew --prefix docker-compose 2>/dev/null || true)"

      if [ -n "$compose_prefix" ] && [ -x "$compose_prefix/bin/docker-compose" ]; then
        mkdir -p "$HOME/.docker/cli-plugins"
        ln -sfn "$compose_prefix/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
      fi
    fi
  '';
}
