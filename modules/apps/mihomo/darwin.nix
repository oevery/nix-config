{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  mihomo = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mihomo;
  label = "org.nixos.mihomo";
  stateDir = "/Library/Application Support/Mihomo";
  logDir = "/Library/Logs/Mihomo";
  serviceLog = "${logDir}/mihomo.log";
  runMarker = "/private/var/run/${label}.running";
  configFile = "${stateDir}/config.yaml";
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
  placeholder = pkgs.writeText "mihomo-placeholder.yaml" ''
    mode: rule
    log-level: warning
    port: 0
    socks-port: 0
    redir-port: 0
    tproxy-port: 0
    mixed-port: 0
    allow-lan: false
    external-controller: ""
    tun:
      enable: false
    dns:
      enable: false
  '';
  mihomoctl = pkgs.callPackage ./ctl {
    inherit stateDir configFile logDir runMarker;
    mihomoPath = lib.getExe mihomo;
    serviceName = label;
    placeholderPath = "${placeholder}";
  };
  mihomoctlExe = lib.getExe mihomoctl;
in
{
  environment.systemPackages = [
    mihomo
    mihomoctl
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
