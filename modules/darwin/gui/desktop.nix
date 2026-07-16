{
  host,
  lib,
  pkgs,
  ...
}:

let
  dockApps = [
    "/System/Applications/Apps.app"
    "/System/Applications/System Settings.app"
    "/Applications/Google Chrome.app"
    "/Applications/Zed.app"
  ];

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

  home.packages = [
    pkgs.dockutil
    pkgs.duti
  ];

  # nix-darwin 会先执行 Homebrew，再执行 Home Manager；在应用安装完成后重建 Dock，
  # 避免首次部署时为尚不存在的 cask 应用生成失效条目。
  home.activation.configureDock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.dockutil}/bin/dockutil --remove all --no-restart
    for app in ${lib.escapeShellArgs dockApps}; do
      run ${pkgs.dockutil}/bin/dockutil --add "$app" --no-restart
    done
    run ${pkgs.dockutil}/bin/dockutil \
      --add "/Users/${host.username}/Developer" \
      --view grid \
      --display folder \
      --sort name \
      --no-restart
    run /usr/bin/killall Dock || true
  '';

  # Homebrew cask 会先于 Home Manager 激活，因此此时 Zed 已可供 Launch Services 使用。
  home.activation.setZedFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for extension in ${lib.escapeShellArgs zedFileExtensions}; do
      run ${pkgs.duti}/bin/duti -s dev.zed.Zed ".$extension" all
    done
  '';
}
