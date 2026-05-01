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
    ];

    # GUI 应用分组：推荐与理由见下方注释。
    casks = [
      # 终端与开发（casks 推荐，更新快、无商店依赖）
      # "iterm2" # 终端
      "visual-studio-code" # 编辑器

      # 效率工具
      # "raycast" # 快捷启动
      "stats" # 系统监控
      # "alt-tab" # 窗口切换

      # 浏览器
      "google-chrome"

      # 密码管理
      "bitwarden"

      # 通讯协作（如微信/QQ/Telegram，casks 更稳，mas 可能因地区/账号失败）
      "wechat"
      "telegram"

      # 媒体与内容
      # "iina" # 播放器
      # "obsidian" # 笔记
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
