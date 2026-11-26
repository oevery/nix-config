{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  multica = pkgs.callPackage ../../../pkgs/multica { };
  omp = inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.omp;
  hasToken = pkgs.writeShellScript "multica-has-token" ''
    exec ${lib.getExe pkgs.jq} -es 'length == 1 and (.[0].token | type == "string" and length > 0)' "$1" >/dev/null 2>&1
  '';
  taskPath = lib.concatStringsSep ":" [
    "${omp}/bin"
    "${multica}/bin"
    "${config.home.profileDirectory}/bin"
    "${config.xdg.dataHome}/mise/shims"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
in
{
  home.packages = [
    multica
    omp
  ];

  systemd.user.services.multica-daemon = {
    Unit = {
      Description = "Multica agent runner";
      ConditionPathExists = "%h/.multica/config.json";
    };
    Service = {
      ExecCondition = "${hasToken} %h/.multica/config.json";
      ExecStart = "${multica}/bin/multica daemon start --foreground --no-auto-update";
      Environment = "PATH=${taskPath}";
      UnsetEnvironment = "MULTICA_SERVER_URL MULTICA_PROFILE";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
