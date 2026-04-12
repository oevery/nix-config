{ config, pkgs, ... }:

let
  commonAliases = {
    cat = "bat";
    catp = "bat -p";
    man = "batman";
    bgrep = "batgrep";

    flu = "nix flake update --flake ~/.config/home-manager";
    hms = "home-manager switch --flake ~/.config/home-manager";
    gc = "nix-collect-garbage -d";
  };
in

{
  home.packages = with pkgs; [
    zsh
    nushell
    nix-your-shell
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = commonAliases // {
      sysup = "sudo apt update && sudo apt upgrade";
    };
    plugins = [
      {
        name = "zsh-autopair";
        src = pkgs.zsh-autopair;
        file = "share/zsh/zsh-autopair/zsh-autopair.plugin.zsh";
      }
      {
        name = "you-should-use";
        src = pkgs.zsh-you-should-use;
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];
    initContent = builtins.readFile ./zsh-extra.sh;
  };

  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    shellAliases = commonAliases;
  };

  programs.nix-your-shell = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };
}
