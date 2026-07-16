{ lib, pkgs, ... }:

let
  zedFileExtensions = [
    "md"
    "json"
    "jsonc"
    "yaml"
    "yml"
    "toml"
    "nix"
    "js"
    "mjs"
    "cjs"
    "jsx"
    "ts"
    "mts"
    "cts"
    "tsx"
    "vue"
    "svelte"
    "astro"
    "css"
    "scss"
    "py"
    "rs"
    "go"
    "java"
  ];
in

lib.mkIf pkgs.stdenv.isDarwin {
  # 在图形终端中隐藏登录提示信息。
  home.file.".hushlogin".text = "";

  home.packages = [ pkgs.duti ];

  # Homebrew cask 会先于 Home Manager 激活，因此此时 Zed 已可供 Launch Services 使用。
  home.activation.setZedFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for extension in ${lib.escapeShellArgs zedFileExtensions}; do
      ${pkgs.duti}/bin/duti -s dev.zed.Zed ".$extension" all
    done
  '';
}
