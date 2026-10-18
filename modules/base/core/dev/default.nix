{
  pkgs,
  host,
  inputs,
  ...
}:

{
  home.packages =
    with pkgs;
    (
      [
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
      color.ui = "auto";
      # Home Manager 中 `pager` 需放在 `core` 下。
      core = {
        pager = "delta";
      };

      interactive = {
        diffFilter = "delta --color-only --paging=never";
      };

      # 确保 Git 使用由 Nix 管理的 gpg 二进制，避免签名失败。
      gpg = {
        program = "${pkgs.gnupg}/bin/gpg";
      };

      delta = {
        paging = "auto";
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

  # 由 GPG 模块安装 gnupg，确保 gpg 与 gpg-agent 来自同一包集。
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    # 按主机的实际交互环境选择，不以包是否存在判断图形会话。
    pinentry.package = pkgs.${host.pinentryPackage};
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
    # 新版包含 GitHub TSA 信任根更新，保留工具来源证明校验。
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        disable_backends = [
          "asdf"
          "vfox"
        ];
        github.credential_command = "gh auth token";
        npm.package_manager = "npm";
        pipx.uvx = true;
      };
      tools = {
        # mise 自身辅助工具。
        usage = "latest";

        # 独立 CLI 工具。
        rtk = "latest";
        # 固定 RC 版本，产物与上游校验信息由 mise 自动解析；索引和服务单独接入。
        "github:xerj-org/xerj" = {
          version = "1.0.0-rc.96";
          version_prefix = "v";
          # Linux 使用静态 musl 产物，避免依赖宿主 glibc。
          platforms.linux-x64.asset_pattern = "xerj-*-x86_64-unknown-linux-musl.tar.gz";
        };

        # Java 工具链。
        java = "temurin-21";
        maven = "latest";

        # Node.js 工具链。
        node = "lts";
        pnpm = "latest";
        "npm:@antfu/ni" = "latest";
        "npm:@larksuite/cli" = "latest";
        "npm:@playwright/mcp" = "latest";
        "npm:@upstash/context7-mcp" = "latest";
        "npm:@dbx-app/cli" = "latest";
        "npm:@dbx-app/mcp-server" = "latest";
        "npm:@bitkyc08/opencodex" = {
          version = "latest";
          npm_args = "--allow-scripts=bun";
        };
        "npm:zread_cli" = "latest";
        "npm:sfw" = "latest";

        # Python 工具链。
        python = "latest";
        uv = "latest";
        "pipx:docling" = {
          version = "latest";
          uvx_args = "--with rapidocr-onnxruntime";
        };

        # Rust 工具链由 mise 调用用户目录中的 rustup 管理，首次安装时自动初始化。
        rust = "latest";
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
