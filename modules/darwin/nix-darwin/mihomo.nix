{
  host,
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
  stdoutLog = "${logDir}/stdout.log";
  stderrLog = "${logDir}/stderr.log";
  configFile = "${stateDir}/config.yaml";
  quote = lib.escapeShellArg;
  logrotateConfig = pkgs.writeText "mihomo-logrotate.conf" ''
    "${stdoutLog}" "${stderrLog}" {
      size 10M
      rotate 5
      compress
      copytruncate
      missingok
    }
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
  mihomoctl = pkgs.callPackage ../../../pkgs/mihomoctl {
    inherit stateDir configFile;
    mihomoPath = lib.getExe mihomo;
    serviceName = label;
    placeholderPath = "${placeholder}";
  };
  mihomoctlExe = lib.getExe mihomoctl;
in
lib.mkIf (host.enableMihomo or false) {
  environment.systemPackages = [
    mihomo
    mihomoctl
  ];

  system.activationScripts.preActivation.text = ''
    for path in ${quote stateDir} ${quote logDir} ${quote configFile} ${quote stdoutLog} ${quote stderrLog}; do
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
    ${mihomoctlExe} --skip-boot-autostart || exit 1
  '';

  launchd.daemons.mihomo = {
    command = "${lib.getExe mihomo} -d ${quote stateDir} -f ${quote configFile}";
    serviceConfig = {
      Label = label;
      UserName = "root";
      GroupName = "admin";
      ThrottleInterval = 10;
      Umask = 18;
      StandardOutPath = stdoutLog;
      StandardErrorPath = stderrLog;
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
      StandardErrorPath = stderrLog;
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
