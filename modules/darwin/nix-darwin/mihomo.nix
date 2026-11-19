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
in
lib.mkIf (host.enableMihomo or false) {
  environment.systemPackages = [
    mihomo
    mihomoctl
  ];

  system.activationScripts.preActivation.text = ''
    for path in ${quote stateDir} ${quote logDir} ${quote configFile}; do
      if [ -L "$path" ]; then
        printf 'Mihomo：不允许使用符号链接：%s\n' "$path" >&2
        exit 1
      fi
    done
    /usr/bin/install -d -o root -g wheel -m 0700 ${quote stateDir} ${quote logDir} || exit 1
    if [ ! -e ${quote configFile} ]; then
      /usr/bin/install -o root -g wheel -m 0600 ${placeholder} ${quote configFile} || exit 1
    fi
  '';

  launchd.daemons.mihomo = {
    command = "${lib.getExe mihomo} -d ${quote stateDir} -f ${quote configFile}";
    serviceConfig = {
      Label = label;
      UserName = "root";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      Umask = 63;
      StandardOutPath = stdoutLog;
      StandardErrorPath = stderrLog;
    };
  };

  launchd.daemons.mihomo-logrotate = {
    command = "${lib.getExe' pkgs.logrotate "logrotate"} --state ${quote "${stateDir}/logrotate.status"} ${logrotateConfig}";
    serviceConfig = {
      Label = "${label}.logrotate";
      UserName = "root";
      Umask = 63;
      StartCalendarInterval = {
        Minute = 0;
      };
    };
  };
}
