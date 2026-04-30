{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.isDarwin {
  programs.zsh.shellAliases = {
    # 安装所有可用的 macOS 系统更新。
    sysup = "softwareupdate -ia";
    # 当应用关联异常时，重建 Launch Services 索引。
    lsreset = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user";
    # 优先使用当前 hostname 作为 darwin target，失败后回退到仓库预置主机名。
    drs = "hc && (nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#$(hostname) || nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#macbook-air)";
    # 调试版：带 --show-trace，策略与 drs 一致。
    drst = "hc && (nix run nix-darwin#darwin-rebuild -- switch --show-trace --flake ~/.config/home-manager#$(hostname) || nix run nix-darwin#darwin-rebuild -- switch --show-trace --flake ~/.config/home-manager#macbook-air)";
  };

  home.sessionVariables = {
    BROWSER = "open -a 'Google Chrome'";
  };
}
