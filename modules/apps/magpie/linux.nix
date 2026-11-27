assets:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ensureMagpie = pkgs.callPackage ./installer.nix {
    assetName = assets.${pkgs.stdenv.hostPlatform.parsed.cpu.name};
  };
  envFile = "${config.xdg.configHome}/magpie-service/env";
  hasWebKey = pkgs.writeShellScript "magpie-has-web-key" ''
    test -n "''${MAGPIE_WEB_KEY:-}"
  '';
in
{
  home.activation.ensureMagpie =
    lib.hm.dag.entryBetween [ "installPackages" "linkGeneration" ] [ "writeBoundary" ]
      ''
        run ${lib.getExe ensureMagpie}
      '';

  systemd.user.services.magpie = {
    Unit = {
      Description = "Magpie 模型网关与管理界面";
      ConditionPathExists = envFile;
    };
    Service = {
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:%h/.local/bin:/usr/local/bin:/usr/bin:/bin"
        "MAGPIE_ADDR=127.0.0.1:63425"
        "MAGPIE_WEB_ADDR=127.0.0.1:63430"
      ];
      EnvironmentFile = envFile;
      ExecCondition = "${hasWebKey}";
      ExecStart = "%h/.local/bin/magpie serve --web=\${MAGPIE_WEB_ADDR}";
      Restart = "on-failure";
      RestartSec = 10;
      UMask = "0077";
      StandardOutput = "null";
      StandardError = "null";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
