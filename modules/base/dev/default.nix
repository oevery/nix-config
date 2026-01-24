{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    gh
    mise

    sqlite

    nixd # A feature-rich nix language server
    nixfmt # Nix code formatter following the Nixpkgs RFC
  ];

  programs.git = {
    enable = true;
    settings = {
      user.email = "oevery";
      user.name = "i@oevery.me";
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
    # High-performance caching for Nix shell environments
    nix-direnv.enable = true;
    enableZshIntegration = true;
    mise.enable = true;
    # Optional: Silencing the direnv noise in the terminal
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
        node = "lts";
        pnpm = "latest";
        "npm:@antfu/ni" = "latest";
        "npm:sfw" = "latest";
      };
    };
  };

  # configuration for .nirc file used by ni
  home.file.".nirc".text = ''
    defaultAgent=pnpm
    globalAgent=pnpm
    runAgent=node
    useSfw=true
  '';
}
