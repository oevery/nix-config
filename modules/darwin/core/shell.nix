{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.isDarwin {
  programs.zsh.shellAliases = {
    # 安装所有可用的 macOS 系统更新。
    sysup = "softwareupdate -ia";
    # 当应用关联异常时，重建 Launch Services 索引。
    lsreset = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user";
  };

  home.sessionVariables = {
    BROWSER = "open";
  };
}
