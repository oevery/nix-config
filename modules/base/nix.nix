{
  config,
  pkgs,
  inputs,
  ...
}:
{
  nix.package = pkgs.nix;
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  systemd.user.startServices = "sd-switch";
}
