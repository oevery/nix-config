{
  lib,
  pkgs,
  host,
  ...
}:

let
  darwinTarget = host.darwinName;
in
lib.mkIf pkgs.stdenv.isDarwin {
  programs.zsh.shellAliases = {
    # 安装所有可用的 macOS 系统更新。
    sysup = "softwareupdate -ia";
    # 当应用关联异常时，重建 Launch Services 索引。
    lsreset = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user";
    # 使用主机配置中的稳定 darwinName，避免与运行时 hostname 耦合。
    drs = "hc && sudo nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#${darwinTarget}";
    # 调试版：带 --show-trace。
    drst = "hc && sudo nix run nix-darwin#darwin-rebuild -- switch --show-trace --flake ~/.config/home-manager#${darwinTarget}";
  };

  home.sessionVariables = {
    BROWSER = "open -a 'Google Chrome'";
  };
}
