{ host, pkgs, ... }:

let
  cleanerPackage = import ../../base/core/kilo-cleaner/package.nix {
    inherit pkgs;
    orphanKiloWithMcpGraceSeconds = host.orphanKiloWithMcpGraceSeconds;
  };
  homeDirectory = "/Users/${host.username}";
  logPath = "${homeDirectory}/.local/state/kilo-cleaner/launchd.log";
in
{
  launchd.user.agents.kilo-cleaner = {
    script = ''
      exec ${cleanerPackage}/bin/kilo-cleaner
    '';

    environment = {
      PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
    };

    serviceConfig = {
      Label = "me.oevery.kilo-cleaner";
      KeepAlive = false;
      RunAtLoad = true;
      StartInterval = 21600;
      StandardOutPath = logPath;
      StandardErrorPath = logPath;
    };
  };
}
