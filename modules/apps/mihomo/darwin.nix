{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (import ./packages.nix { inherit inputs lib pkgs; })
    mihomo label stateDir logDir runMarker configFile placeholder ctl;
  serviceLog = "${logDir}/mihomo.log";
  quote = lib.escapeShellArg;
  logrotateConfig = pkgs.writeText "mihomo-logrotate.conf" ''
    "${serviceLog}" {
      size 10M
      rotate 5
      compress
      copytruncate
      missingok
    }
  '';
  launcher = pkgs.writeShellScript "mihomo-system-launch" ''
    test -f ${quote runMarker} || exit 0
    exec ${lib.getExe mihomo} -d ${quote stateDir} -f ${quote configFile}
  '';
  mihomoctlExe = lib.getExe ctl;
in
{
  environment.systemPackages = [
    mihomo
    ctl
  ];

  system.activationScripts.preActivation.text = ''
    for path in ${quote stateDir} ${quote logDir} ${quote configFile} ${quote serviceLog}; do
      if [ -L "$path" ]; then
        printf 'Mihomo：不允许使用符号链接：%s\n' "$path" >&2
        exit 1
      fi
    done
    for dir in ${quote stateDir} ${quote logDir}; do
      if [ ! -d "$dir" ]; then
        /usr/bin/install -d -o root -g admin -m 0755 "$dir" || exit 1
      fi
    done
    if [ ! -e ${quote configFile} ]; then
      /usr/bin/install -o root -g admin -m 0644 ${placeholder} ${quote configFile} || exit 1
    fi
    if [ ! -e ${quote serviceLog} ]; then
      /usr/bin/install -o root -g admin -m 0640 /dev/null ${quote serviceLog} || exit 1
    fi
    ${mihomoctlExe} --skip-boot-autostart || exit 1
  '';

  launchd.daemons.mihomo = {
    serviceConfig = {
      Label = label;
      ProgramArguments = [ "${launcher}" ];
      UserName = "root";
      GroupName = "admin";
      ThrottleInterval = 10;
      KeepAlive.PathState.${runMarker} = true;
      Umask = 63;
      StandardOutPath = serviceLog;
      StandardErrorPath = serviceLog;
    };
  };

  launchd.daemons.mihomo-autostart = {
    command = "${mihomoctlExe} --run-boot-autostart";
    serviceConfig = {
      Label = "${label}.autostart";
      UserName = "root";
      GroupName = "admin";
      RunAtLoad = true;
      Umask = 18;
      StandardErrorPath = serviceLog;
    };
  };

  launchd.daemons.mihomo-logrotate = {
    command = "${lib.getExe' pkgs.logrotate "logrotate"} --state /dev/null ${logrotateConfig}";
    serviceConfig = {
      Label = "${label}.logrotate";
      UserName = "root";
      GroupName = "admin";
      Umask = 18;
      StartCalendarInterval = {
        Minute = 0;
      };
    };
  };
}
