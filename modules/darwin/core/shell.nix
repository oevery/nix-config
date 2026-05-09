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
    # 不要用 sudo 来运行 darwin-rebuild；直接以普通用户运行，darwin-rebuild
    # 会在需要时请求权限提升（提示 sudo），避免文件属主被错误设置为 root。
    drs = "hc && nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#${darwinTarget}";
    # 调试版：带 --show-trace。
    drst = "hc && nix run nix-darwin#darwin-rebuild -- switch --show-trace --flake ~/.config/home-manager#${darwinTarget}";
  };

  home.sessionVariables = {
    BROWSER = "open -a 'Google Chrome'";
  };
}
