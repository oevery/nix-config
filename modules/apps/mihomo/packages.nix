{ inputs, pkgs, lib, ... }:
let
  mihomo = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mihomo;
  state = "/var/lib/mihomo";
  linuxCtl = pkgs.callPackage ./ctl {
    stateDir = state;
    configFile = "${state}/config.yaml";
    mihomoPath = lib.getExe mihomo;
    serviceName = "mihomo.service";
    validationUnit = "${unit}/lib/systemd/system/mihomo.service";
  };
  unit = pkgs.writeTextDir "lib/systemd/system/mihomo.service" ''
    [Unit]
    Description=Mihomo system TUN
    After=network.target NetworkManager.service systemd-networkd.service iwd.service
    [Service]
    Type=simple
    User=root
    LimitNOFILE=1000000
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
    ExecCondition=/usr/bin/test -s ${state}/config.yaml
    ExecStart=${lib.getExe mihomo} -d ${state} -f ${state}/config.yaml
    ExecReload=/bin/kill -HUP $MAINPID
    Restart=always
    RestartSec=5s
    NoNewPrivileges=yes
    UMask=0077
    StandardOutput=journal
    StandardError=inherit
    [Install]
    WantedBy=multi-user.target
  '';
  label = "org.nixos.mihomo";
  stateDir = "/Library/Application Support/Mihomo";
  logDir = "/Library/Logs/Mihomo";
  runMarker = "/private/var/run/${label}.running";
  configFile = "${stateDir}/config.yaml";
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
in {
  inherit mihomo unit label stateDir logDir runMarker configFile placeholder;
  ctl = if pkgs.stdenv.isLinux then linuxCtl else pkgs.callPackage ./ctl {
    inherit stateDir configFile logDir runMarker;
    mihomoPath = lib.getExe mihomo;
    serviceName = label;
    placeholderPath = "${placeholder}";
  };
}
