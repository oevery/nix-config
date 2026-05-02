{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 系统监控
    btop # 现代化的 top 替代品

    # 文本与命令行效率工具
    eza # 现代化的 ls 替代品
    bat # 现代化的 cat 替代品
    fd # 快速文件查找工具（fzf 默认命令依赖）
    fzf # 通用命令行模糊查找器
    vivid # 终端配色与高亮主题工具
    zoxide # 更智能的 cd 命令

    # 磁盘工具
    duf # Rust 实现的更友好 df
    dust # Rust 实现的更直观 du
    gdu # 磁盘占用分析器（du 替代）

    # 杂项工具
    fastfetch # 系统信息展示工具
    tealdeer # Rust 实现的高速 tldr 客户端
  ];

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "always";
    colors = "always";
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--octal-permissions"
      "--hyperlink"
      "--modified"
      "--time-style=long-iso"
      "--color-scale"
    ];
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      style = "numbers,changes,header";
      pager = "less -FR";
    };
    extraPackages = with pkgs.bat-extras; [
      batdiff
      batman
      batgrep
      batwatch
    ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "--color='fg:#abb2bf,bg:-1,hl:#61afef,fg+:#abb2bf,bg+:#3e4452,hl+:#61afef'"
      "--color='info:#98c379,prompt:#c678dd,pointer:#e06c75,marker:#e5c07b,spinner:#61afef,header:#61afef'"
    ];
    fileWidgetCommand = "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat --style=numbers --color=always --line-range :500 {}; fi'"
    ];
    changeDirWidgetCommand = "fd --type d --strip-cwd-prefix --hidden --follow --exclude .git";
    changeDirWidgetOptions = [ "--preview 'eza --tree --color=always {} | head -200'" ];
  };

  programs.vivid = {
    enable = true;
    enableZshIntegration = true;
    activeTheme = "one-dark";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd cd"
    ];
  };

  programs.tealdeer = {
    enable = true;
    enableAutoUpdates = true;
  };
}
