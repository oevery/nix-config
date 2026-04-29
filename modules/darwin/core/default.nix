{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    exclude = [
      "default.nix"
      "system.nix"
    ];
  };
}
