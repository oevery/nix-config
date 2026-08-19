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
      "watchman" # 文件变更监听工具，常用于前端/移动端开发。
      # "omlx" # 本地 LLM 推理与管理后台。
      # 容器运行时改由 OrbStack 提供，旧 Docker 工具保留为注释。
      # "colima" # 轻量容器运行时。
      # "docker" # Docker CLI。
      # "docker-compose" # Docker Compose。
    ];
  };
}
