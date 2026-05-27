{
  host,
  lib,
  pkgs,
  ...
}:

let
  cleanerPackage = import ./package.nix {
    inherit pkgs;
    orphanKiloWithMcpGraceSeconds = host.orphanKiloWithMcpGraceSeconds;
  };
in
{
  home.packages = [ cleanerPackage ];

  home.activation.ensureKiloCleanerStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/kilo-cleaner"
  '';

}
// lib.mkIf pkgs.stdenv.isLinux {
  systemd.user.services.kilo-cleaner = {
    Unit = {
      Description = "Clean stale kilo and mcp processes";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${cleanerPackage}/bin/kilo-cleaner";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.findutils
            pkgs.gawk
            pkgs.procps
          ]
        }"
      ];
    };
  };

  systemd.user.timers.kilo-cleaner = {
    Unit = {
      Description = "Run kilo-cleaner daily";
    };

    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "kilo-cleaner.service";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
