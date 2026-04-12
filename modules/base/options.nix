{
  lib,
  config,
  pkgs,
  ...
}:

{
  options.myOpts = {
    username = lib.mkOption { type = lib.types.str; };
    email = lib.mkOption { type = lib.types.str; };
    gitName = lib.mkOption { type = lib.types.str; };
    gpgKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = {
    # auto fill in the username and home directory based on the options defined above
    home.username = config.myOpts.username;
    home.homeDirectory =
      if pkgs.stdenv.isDarwin then
        "/Users/${config.myOpts.username}"
      else
        "/home/${config.myOpts.username}";

    # Git configuration: automatically use the variables defined above
    programs.git = {
      settings = {
        user.email = config.myOpts.email;
        user.name = config.myOpts.gitName;
      };
      signing = {
        key = config.myOpts.gpgKey;
        signByDefault = config.myOpts.gpgKey != null;
      };
    };
  };
}
