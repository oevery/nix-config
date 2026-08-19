{ host, pkgs, ... }:

let
  brewupPackage = import ./package.nix {
    inherit pkgs;
    darwinName = host.darwinName;
  };
in
{
  home.packages = [ brewupPackage ];
}
