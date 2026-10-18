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
      "watchman" # 文件变更监听工具，常用于前端/移动端开发。
    ];
  };
}
