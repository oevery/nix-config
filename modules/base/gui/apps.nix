{ pkgs, ... }:

{
  # 在跨平台层提供可选 GUI 应用；是否启用由 host 的 modules 决定。
  # 当前 mac 默认关闭该模块，优先通过 Homebrew 安装同类应用。
  home.packages = with pkgs; [
    # 开发工具
    vscode # 编辑器
    reqable # API 调试工具
  ];
}
