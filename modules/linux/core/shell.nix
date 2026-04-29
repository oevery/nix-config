{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  programs.zsh.shellAliases = {
    sysup = "sudo apt update && sudo apt upgrade";
  };
}
