{ lib, ... }:

let
  entries = builtins.readDir ./.;
  validFiles = lib.filterAttrs (
    name: type:
    (type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    || (type == "directory" && builtins.pathExists (./. + "/${name}/default.nix"))
  ) entries;
  importPaths = map (name: ./. + "/${name}") (lib.attrNames validFiles);
in
{
  imports = importPaths;
}
