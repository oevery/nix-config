{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    exclude = [
      "system.nix"
      "kilo-cleaner.nix"
    ];
  };
}
