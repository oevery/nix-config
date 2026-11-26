{
  lib,
  pkgs,
  host,
  ...
}:

let
  switchScript =
    name: flags:
    pkgs.writeShellScriptBin name ''
      set -eu
      hc
      exec home-manager switch ${lib.escapeShellArgs flags} --flake "$HOME/.config/home-manager#${host.homeConfigurationName}"
    '';
in
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [
    (switchScript "hms" [ ])
    (switchScript "hmst" [ "--show-trace" ])
  ];

  programs.zsh.shellAliases = {
    sysup = "sudo apt update && sudo apt upgrade";
  };
}
