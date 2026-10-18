{
  lib,
  pkgs,
  host,
  ...
}:

let
  shellConfig = import ./nix-config.nix;

  checkScript = pkgs.writeShellScriptBin "hc" ''
    set -eu

    flake_path="$HOME/.config/home-manager"
    nix eval --raw --no-write-lock-file \
      "$flake_path#homeConfigurations.${host.homeConfigurationName}.activationPackage.drvPath"
    printf '\n'
    ${lib.optionalString pkgs.stdenv.isDarwin ''
      nix eval --raw --no-write-lock-file \
        "$flake_path#darwinConfigurations.${host.darwinName}.config.system.build.toplevel.drvPath"
      printf '\n'
    ''}
  '';

  fluScript = pkgs.writeShellScriptBin "flu" ''
        set -eu

        if ! command -v nix >/dev/null 2>&1; then
          printf '%s\n' 'flu: nix command not found' >&2
          exit 127
        fi

    ${shellConfig.githubAccessTokensSnippet}

        exec nix flake update --flake "$HOME/.config/home-manager" "$@"
  '';

  commonAliases = {
    cat = "bat";
    catp = "bat --style=plain --color=never --paging=never";
    man = "batman";
    bgrep = "batgrep";

    nix-gc-delete-all-old-generations = "nix-collect-garbage -d";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    hms = "${checkScript}/bin/hc && home-manager switch --flake ~/.config/home-manager#${host.homeConfigurationName}";
  };
in

{
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    # 导出 Copilot OTEL 遥测。
    COPILOT_OTEL_ENABLED = "true";
    COPILOT_OTEL_EXPORTER_TYPE = "file";
  };

  # `home.sessionVariables` 会转义 shell 特殊字符，这里改用额外 shell 片段实现按天轮转。
  home.sessionVariablesExtra = ''
    export COPILOT_OTEL_FILE_EXPORTER_PATH="$HOME/.copilot/otel/copilot-otel-$(date +%Y%m%d).jsonl"
  '';

  home.activation.ensureCopilotOtelDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.copilot/otel"
  '';

  home.packages = [
    fluScript
    checkScript
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    envExtra = ''
      # 部分终端前端不会为本地 PTY 设置 TERM；在插件加载前补齐安全默认值。
      if [[ -o interactive && -t 0 && -z "''${TERM:-}" ]]; then
        export TERM=xterm-256color
      fi
    '';
    shellAliases = commonAliases;
    initContent = builtins.readFile ./zsh-extra.sh;
    plugins = [
      {
        name = "zsh-autopair";
        src = pkgs.zsh-autopair;
        file = "share/zsh/zsh-autopair/zsh-autopair.plugin.zsh";
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];
  };

  # programs.nushell = {
  #   enable = true;
  #   configFile.source = ./config.nu;
  #   shellAliases = commonAliases;
  # };

  programs.nix-your-shell = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };
}
