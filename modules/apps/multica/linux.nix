assets:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ensureMultica = pkgs.callPackage ./installer.nix {
    assetPlatform = assets.${pkgs.stdenv.hostPlatform.parsed.cpu.name};
  };
  hasToken = pkgs.writeShellScript "multica-has-token" ''
    exec ${lib.getExe pkgs.jq} -es 'length == 1 and (.[0].token | type == "string" and length > 0)' "$1" >/dev/null 2>&1
  '';
  taskPath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.xdg.dataHome}/mise/shims"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
in
{
  home.activation.ensureMultica =
    lib.hm.dag.entryBetween [ "installPackages" "linkGeneration" ] [ "writeBoundary" ]
      ''
        run ${lib.getExe ensureMultica}
      '';

  systemd.user.services.multica-daemon = {
    Unit = {
      Description = "Multica 任务执行节点";
      ConditionPathExists = "%h/.multica/config.json";
    };
    Service = {
      ExecCondition = "${hasToken} %h/.multica/config.json";
      ExecStart = "%h/.local/bin/multica daemon start --foreground --no-auto-update";
      Environment = "PATH=${taskPath}";
      UnsetEnvironment = "MULTICA_SERVER_URL MULTICA_PROFILE";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
