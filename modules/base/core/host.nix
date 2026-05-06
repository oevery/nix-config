{
  host,
  pkgs,
  ...
}:

let
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${host.username}" else "/home/${host.username}";
in
{
  home.username = host.username;
  home.homeDirectory = homeDirectory;

  programs.git = {
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
