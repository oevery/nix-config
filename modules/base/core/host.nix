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
  device = lib.removePrefix "${host.username}-" host.homeConfigurationName;
  signingFile = ../../../secrets + "/git-signing/${device}.yaml";
  hasSigningFile = builtins.pathExists signingFile;
  signingDir = "${config.home.homeDirectory}/.config/git/signing";
  signingTools = lib.makeBinPath [
    pkgs.sops
    config.programs.gpg.package
  ];
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
    secrets."git/ssh-key-01".key = "ssh_key_01";
  };

  programs.git = {
    includes =
      lib.optional hasSigningFile { path = "${signingDir}/default.inc"; }
      ++ lib.optional privateGit { path = config.sops.secrets."git/routing.inc".path; };

    settings = {
      user = {
        email = host.email;
        name = host.gitName;
      };
    };

    signing = {
      key = "";
      signByDefault = false;
    };
  };

  home.activation.gitSigning = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if hasSigningFile then
      ''
        run env PATH="${signingTools}:$PATH" \
          SOPS_AGE_KEY_FILE="${config.xdg.configHome}/sops/age/keys.txt" \
          ${pkgs.python3}/bin/python3 ${./git-signing.py} "${signingDir}" "${signingFile}"
      ''
    else
      ''
        if [[ -d "${signingDir}" ]]; then
          run ${pkgs.python3}/bin/python3 ${./git-signing.py} "${signingDir}"
        fi
      ''
  );
}
