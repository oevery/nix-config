{
  config,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  privateGit = host.enablePrivateGit or false;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  home.username = host.username;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${host.username}" else "/home/${host.username}";

  home.packages = lib.optionals privateGit [
    pkgs.age
    pkgs.sops
  ];
  sops = lib.mkIf privateGit {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    defaultSopsFile = ../../../secrets/git.yaml;
    secrets."git/routing.inc".key = "routing";
    secrets."git/profile-01.inc".key = "profile_01";
  };

  programs.git = {
    includes = lib.optional privateGit {
      path = config.sops.secrets."git/routing.inc".path;
    };

    settings = {
      user = {
        email = host.email;
        name = host.gitName;
      };
    };

    signing = {
      key = host.gpgKey or null;
      signByDefault = (host.gpgKey or null) != null;
    };
  };
}
