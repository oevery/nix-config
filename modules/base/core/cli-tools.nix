{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    btop # 现代化的 top 替代品

    # 命令行效率工具
    ripgrep # 快速递归文本搜索工具 (rg)
    fd # 快速文件查找工具（fzf 默认命令依赖）
    ast-grep # 基于语法结构的代码搜索与改写。
    hyperfine # 命令行基准测试与重复计时。

    # 磁盘工具
    duf # Rust 实现的更友好 df
    gdu # 磁盘占用分析器（du 替代）

    # 其他常用工具
    fastfetch # 系统信息展示工具
    ffmpeg # 音视频处理工具

    jq
    yq
    duckdb # 使用 SQL 查询和汇总 JSON、CSV、Parquet 数据。
    delta
    lazygit
    glow
  ];

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    # 交互终端保留美化，管道和 Agent 捕获输出时不强制装饰。
    icons = "auto";
    colors = "auto";
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--octal-permissions"
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
      color = "auto";
      decorations = "auto";
      paging = "auto";
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
      "--preview 'if [ -d {} ]; then eza --tree --color=always --icons=always {} | head -200; else bat --paging=never --decorations=always --style=numbers --color=always --line-range :500 {}; fi'"
    ];
    changeDirWidgetCommand = "fd --type d --strip-cwd-prefix --hidden --follow --exclude .git";
    changeDirWidgetOptions = [ "--preview 'eza --tree --color=always --icons=always {} | head -200'" ];
  };

  programs.vivid = {
    enable = true;
    # Work around home-manager#8862. Remove this override after the upstream
    # fix from home-manager#9156 (or an equivalent fix) is released.
    enableZshIntegration = false;
    activeTheme = "one-dark";
  };

  programs.zsh.initContent = lib.mkBefore ''
    export LS_COLORS="$(${pkgs.vivid}/bin/vivid generate one-dark)"
  '';

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
