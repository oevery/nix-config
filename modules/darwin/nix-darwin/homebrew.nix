{ ... }:

{
  # macOS 下通过 Homebrew 管理的 CLI 工具与更新策略。
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    # macOS 专用 CLI。
    brews = [
      "mas"
      "mole" # 系统清理工具。
      "ios-deploy" # iOS 真机安装与调试。
      # "omlx" # 本地 LLM 推理与管理后台。
      # "mm7894215/tokentracker/tokentracker" # AI token 用量采集 CLI。
      # 容器运行时由 Colima 提供。
      "colima" # 轻量容器运行时。
      "docker" # Docker CLI。
      "docker-compose" # Docker Compose。
    ];
  };
}
