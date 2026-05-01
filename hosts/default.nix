{ myLib }:

let
  common = import ./common.nix;
  inherit (myLib) mkHost;
in
{
  "oevery@homelab" = import ./oevery-homelab.nix { inherit mkHost common; };
  "oevery@oevery-desktop" = import ./oevery-desktop.nix { inherit mkHost common; };
  "oevery@mac" = import ./oevery-mac.nix { inherit mkHost common; };
}
