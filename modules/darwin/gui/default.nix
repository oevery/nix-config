{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    # homebrew.nix 是 nix-darwin 系统模块，不应被 Home Manager 自动导入。
    exclude = [
      "default.nix"
      "homebrew.nix"
    ];
  };
}
