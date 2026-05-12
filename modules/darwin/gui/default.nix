{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    # homebrew.nix 由 nix-darwin 加载。
    exclude = [
      "default.nix"
      "homebrew.nix"
    ];
  };
}
