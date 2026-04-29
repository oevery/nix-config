{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    starship # 轻量、高速、可高度定制的跨 Shell 提示符
  ];

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    settings = fromTOML (builtins.readFile ./starship.toml);
  };
}
