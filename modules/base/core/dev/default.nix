{
  pkgs,
  ...
}:

{
  home.packages =
    with pkgs;
    (
      [
        git
        gh

        rustup
        mise
        rtk

        # 由 Nix 管理 gnupg，确保 gpg 与 gpg-agent 一致。
        gnupg

        # 跨平台 CLI 统一交给 Nix 管理。
        sqlite
        android-tools # adb / fastboot。
        cmake # 原生模块和桌面应用构建工具。
        pkg-config # 本地库编译参数发现工具。

        nixd # Nix 语言服务器。
        nixfmt # Nix 格式化工具。
      ]
      ++ lib.optional stdenv.isDarwin pinentry_mac
    );

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      # Home Manager 中 `pager` 需放在 `core` 下。
      core = {
        pager = "delta";
      };

      interactive = {
        diffFilter = "delta --color-only";
      };

      # 确保 Git 使用由 Nix 管理的 gpg 二进制，避免签名失败。
      gpg = {
        program = "${pkgs.gnupg}/bin/gpg";
      };

      delta = {
        "syntax-theme" = "TwoDark";
        "line-numbers" = true;
      };
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
    # 优先使用图形化 pinentry，不可用时回退到 curses。
    pinentry.package =
      let
        linuxPinentryPackage =
          if pkgs.lib.hasAttr "pinentry-gnome3" pkgs then
            pkgs.pinentry-gnome3
          else if pkgs.lib.hasAttr "pinentry-gtk" pkgs then
            pkgs.pinentry-gtk
          else if pkgs.lib.hasAttr "pinentry-qt" pkgs then
            pkgs.pinentry-qt
          else
            pkgs.pinentry-curses;
      in
      if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else linuxPinentryPackage;
    defaultCacheTtl = 10800;
    maxCacheTtl = 86400;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
    mise.enable = true;
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
        python = "3.11";
        java = "temurin-21";
        uv = "latest";
        "npm:@antfu/ni" = "latest";
        "npm:sfw" = "latest";
      };
    };
  };

  # `ni` 默认使用 pnpm。
  home.file.".nirc".text = ''
    defaultAgent=pnpm
    globalAgent=pnpm
    runAgent=node
    useSfw=true
  '';
}
