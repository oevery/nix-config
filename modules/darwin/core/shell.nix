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
    sysup = "softwareupdate -ia";
    # 重建 Launch Services 索引。
    lsreset = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user";
    # 使用 darwinName，避免依赖运行时 hostname。
    drs = "hc && sudo -H nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#${darwinTarget}";
    # 带 --show-trace 的调试版。
    drst = "hc && sudo -H nix run nix-darwin#darwin-rebuild -- switch --show-trace --flake ~/.config/home-manager#${darwinTarget}";
  };

  home.sessionVariables = {
    BROWSER = "open -a 'Google Chrome'";
  };
}
