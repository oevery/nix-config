{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    gh

    rustup
    mise

    sqlite

    nixd # 功能完善的 Nix 语言服务器
    nixfmt # 遵循 Nixpkgs RFC 的 Nix 格式化工具
  ];

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
        rv = "repo view --web";
      };
      spinner = true;
    };
  };

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-curses;
    defaultCacheTtl = 10800;
    maxCacheTtl = 86400;
  };

  programs.direnv = {
    enable = true;
    # 为 Nix shell 环境提供高性能缓存
    nix-direnv.enable = true;
    enableZshIntegration = true;
    mise.enable = true;
    # 可选：降低 direnv 在终端中的提示噪音
    config.global.warn_timeout = "1m";
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    globalConfig = {
      settings = {
        disable_backends = [
          "asdf"
          "vfox"
        ];
        npm.package_manager = "pnpm";
      };
      tools = {
        usage = "latest";
        rust = "latest";
        node = "lts";
        pnpm = "latest";
        "npm:@antfu/ni" = "latest";
        "npm:sfw" = "latest";
      };
    };
  };

  # ni 使用的 .nirc 配置文件
  home.file.".nirc".text = ''
    defaultAgent=pnpm
    globalAgent=pnpm
    runAgent=node
    useSfw=true
  '';
}
