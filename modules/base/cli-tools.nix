{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # system monitoring
    btop # a modern replacement for 'top'

    # Text Processing
    eza # a modern replacement for 'ls'
    bat # a modern replacement for 'cat'
    fzf # a general-purpose command-line fuzzy finder
    vivid # syntax highlighter for the terminal
    zoxide # a smarter cd command

    # disk
    duf # disk usage free, a better `df` in rust
    dust # a more intuitive version of `du` in rust
    gdu # disk usage analyzer(replacement of `du`)

    # misc
    fastfetch # system information tool
    tealdeer # a very fast implementation of tldr in rust
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
}
