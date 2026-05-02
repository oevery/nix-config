{ mkHost, common }:

mkHost (
  common
  // {
    system = "aarch64-darwin";
    darwinName = "oevery-mac";
    gpgKey = "FF2F947EF8595DC8";
    modules = [
      "base/core"
      # 可选：启用后改为通过 Nix 安装 GUI 应用（如 vscode、reqable）。
      # 默认保持关闭，mac 优先使用 darwin/gui/homebrew.nix。
      # "base/gui"
      "darwin/core"
      "darwin/gui"
    ];
  }
)
