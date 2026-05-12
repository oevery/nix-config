{ pkgs, ... }:

{
  # 可选跨平台 GUI 应用。
  home.packages = with pkgs; [
    # 开发工具
    vscode # 编辑器
    reqable # API 调试工具
  ];
}
