{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    # homebrew.nix 由 nix-darwin 加载。
    exclude = [
      "homebrew.nix"
    ];
  };
}
