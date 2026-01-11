{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    starship # the minimal, blazing-fast, and infinitely customizable prompt for any shell
  ];

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    settings = fromTOML (builtins.readFile ./starship.toml);
  };
}
