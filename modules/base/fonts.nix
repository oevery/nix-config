{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    monaspace
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.enable = true;
}
