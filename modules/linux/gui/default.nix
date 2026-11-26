{
  lib,
  pkgs,
  ...
}:

{
  nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "reqable";

  home.packages = with pkgs; [
    zed-editor
    reqable
  ];
}
