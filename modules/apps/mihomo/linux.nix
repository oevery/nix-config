{ inputs, pkgs, lib, ... }:
let
  inherit (import ./packages.nix { inherit inputs pkgs lib; }) ctl unit;
in {
  home.packages = [ ctl ];
  xdg.dataFile."mihomo/system".source = unit;
}
