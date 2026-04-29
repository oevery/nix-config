{ host, pkgs, ... }:

{
  home.username = host.username;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${host.username}" else "/home/${host.username}";

  programs.git = {
    settings = {
      user.email = host.email;
      user.name = host.gitName;
    };
    signing = {
      key = host.gpgKey or null;
      signByDefault = (host.gpgKey or null) != null;
    };
  };
}
