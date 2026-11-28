{ inputs, pkgs, lib, ... }:
let
  mihomo = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mihomo;
  state = "/var/lib/mihomo";
  ctl = pkgs.callPackage ./ctl {
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
in
{
  home.packages = [ ctl ];
  xdg.dataFile."mihomo/system".source = unit;
}
