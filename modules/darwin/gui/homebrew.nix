{ ... }:

{
  # 在 macOS 上以“声明式”方式管理 Homebrew。
  # 推荐策略：Nix 管开发环境，Homebrew 补少量 GUI/App Store 应用。
  homebrew = {
    enable = true;

    # 首次启用后，执行 darwin-rebuild 时自动更新与清理。
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    # 常见命令行工具（按需增减）。
    brews = [
      "mas"
      "mole" # Mac 清理与优化工具（CLI）
      "ios-deploy" # iOS 真机安装与调试（避免 Nix 在 macOS 上的私有框架构建限制）
    ];

    # GUI 应用分组：已安装与候选项都按用途归类，便于按需启用。
    # 原则：GUI 优先 Homebrew，减少 Nix 对 App Bundle/系统集成的适配成本。
    casks = [
      # 终端与开发
      # "iterm2" # 终端
      "visual-studio-code" # 编辑器
      "hbuilderx" # uni-app 开发 IDE
      "wechatwebdevtools" # 微信开发者工具（小程序/公众号）
      "reqable" # API 调试与代理抓包
      "dbeaver-community" # 数据库管理与 SQL 客户端
      "android-studio" # Android 开发与模拟器

      # 效率工具
      "raycast" # 快捷启动
      "stats" # 系统监控
      # "mos" # 鼠标滚动平滑与方向增强
      # "alt-tab" # 窗口切换
      # "rectangle" # 窗口管理
      "pixpin" # 截图与标注

      # 浏览器
      "google-chrome"
      "firefox"

      # 密码管理
      "bitwarden"

      # 通讯协作
      "wechat"
      "qq"
      "telegram"
      "uuremote" # 网易 UU 远程桌面
      # "rustdesk" # 开源远程桌面

      # 媒体娱乐
      "neteasemusic" # 网易云音乐
      # "obs" # 直播与录屏
      # "iina" # 本地媒体播放器

      # 知识管理
      # "obsidian" # 本地 Markdown 知识库
    ];

    # 推荐放 masApps 的应用：
    # 1. 苹果自家或强依赖 iCloud 的应用
    # 2. 你明确希望走 App Store 更新的应用
    masApps = {
      # "Xcode" = 497799835; # 苹果官方开发工具，强烈推荐 masApps
      # "Numbers" = 409203825;     # 苹果自家办公套件（如有需求可解注）
      # "Keynote" = 409183694;
      # "Pages" = 409201541;
      # "GarageBand" = 682658836;
      # "iMovie" = 408981434;
    };
  };
}
