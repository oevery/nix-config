{
  host,
  lib,
  pkgs,
  ...
}:

let
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${host.username}" else "/home/${host.username}";
  privateGitProfilesPath = "${homeDirectory}/.config/home-manager/.private/git-profiles.nix";

  gitProfiles =
    if builtins.pathExists privateGitProfilesPath then import privateGitProfilesPath else [ ];

  mkProfileIncludeText =
    profile:
    let
      gpgSign = profile.gpgSign or ((profile.gpgKey or null) != null);
    in
    lib.concatStringsSep "\n" (
      [
        "[user]"
        "  name = ${profile.userName}"
        "  email = ${profile.userEmail}"
      ]
      ++ lib.optionals ((profile.gpgKey or null) != null) [ "  signingKey = ${profile.gpgKey}" ]
      ++ [
        ""
        "[commit]"
        "  gpgSign = ${if gpgSign then "true" else "false"}"
      ]
      ++ lib.optionals ((profile.sshKey or null) != null) [
        ""
        "[core]"
        "  sshCommand = ssh -i ${profile.sshKey} -F /dev/null"
      ]
      ++ [ "" ]
    );

  gitProfileFiles = lib.listToAttrs (
    map (profile: {
      name = ".config/git/profiles/${profile.name}.inc";
      value.text = mkProfileIncludeText profile;
    }) gitProfiles
  );
in
{
  home.username = host.username;
  home.homeDirectory = homeDirectory;

  programs.git = {
    settings = {
      user.email = host.email;
      user.name = host.gitName;
    };
    includes = map (profile: {
      condition = "gitdir:${profile.gitdir}";
      path = "~/.config/git/profiles/${profile.name}.inc";
    }) gitProfiles;
    signing = {
      key = host.gpgKey or null;
      signByDefault = (host.gpgKey or null) != null;
    };
  };

  home.file = gitProfileFiles;

}
