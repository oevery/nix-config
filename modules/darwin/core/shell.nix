{
  lib,
  pkgs,
  host,
  ...
}:

let
  shellConfig = import ../../base/core/shell/nix-config.nix;

  rebuildScript =
    traceFlag:
    scriptName:
    pkgs.writeShellScriptBin scriptName ''
      set -eu

      flake_path="$HOME/.config/home-manager"

      if ! command -v nix >/dev/null 2>&1; then
        printf '%s\n' '${scriptName}: nix command not found' >&2
        exit 127
      fi

      sudo_cmd='sudo -H'
${shellConfig.githubAccessTokensSnippet}
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        sudo_cmd='sudo -E -H'
      fi

      nix flake check --no-write-lock-file "$flake_path"

      # 始终通过当前 flake 暴露的 app 调用 `darwin-rebuild`，避免 PATH 中旧版本工具与本仓库输出结构不匹配。
      exec $sudo_cmd nix run "$flake_path#darwin-rebuild" -- switch ${traceFlag}--flake "$flake_path#${host.darwinName}"
    '';
in

lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [
    (rebuildScript "" "drs")
    (rebuildScript "--show-trace " "drst")
  ];

  programs.zsh.shellAliases = {
    sysup = "softwareupdate -ia";
    # 重建 Launch Services 索引。
    lsreset = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user";
  };

  home.sessionVariables = {
    BROWSER = "open -a 'Google Chrome'";
  };
}
