{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  nix.package = pkgs.nix;
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.settings = {
    auto-optimise-store = true;
    keep-outputs = false;
    keep-derivations = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  systemd.user.startServices = "sd-switch";
}
