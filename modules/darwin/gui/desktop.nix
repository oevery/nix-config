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
    "/Applications/Warp.app"
    "/Applications/Google Chrome.app"
    "/Applications/Zed.app"
    "/Applications/ChatGPT.app"
  ];

  zedDynamicFileExtensions = [
    "jsonc"
    "nix"
    "cjs"
    "jsx"
    "cts"
    "vue"
    "svelte"
    "astro"
    "scss"
    "rs"
    "go"
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

  zedFileTypesInfo = pkgs.writeText "zed-file-types-info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDocumentTypes</key>
      <array>
        <dict>
          <key>CFBundleTypeName</key>
          <string>Zed source code</string>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>LSHandlerRank</key>
          <string>Alternate</string>
          <key>LSItemContentTypes</key>
          <array>
            <string>io.github.oevery.zed-source-code</string>
          </array>
        </dict>
      </array>
      <key>CFBundleExecutable</key>
      <string>ZedFileTypes</string>
      <key>CFBundleIdentifier</key>
      <string>io.github.oevery.zed-file-types</string>
      <key>CFBundleName</key>
      <string>ZedFileTypes</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>UTExportedTypeDeclarations</key>
      <array>
        <dict>
          <key>UTTypeConformsTo</key>
          <array>
            <string>public.source-code</string>
            <string>public.text</string>
          </array>
          <key>UTTypeDescription</key>
          <string>Zed source code</string>
          <key>UTTypeIdentifier</key>
          <string>io.github.oevery.zed-source-code</string>
          <key>UTTypeTagSpecification</key>
          <dict>
            <key>public.filename-extension</key>
            <array>
    ${lib.concatMapStringsSep "\n" (
      extension: "              <string>${extension}</string>"
    ) zedDynamicFileExtensions}
            </array>
          </dict>
        </dict>
      </array>
    </dict>
    </plist>
  '';

  zedFileTypesApp = pkgs.runCommand "zed-file-types.app" { } ''
    mkdir -p "$out/Contents/MacOS"
    cp ${zedFileTypesInfo} "$out/Contents/Info.plist"
    cp ${pkgs.coreutils}/bin/true "$out/Contents/MacOS/ZedFileTypes"
  '';
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
    run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -f "${zedFileTypesApp}"
    for extension in ${lib.escapeShellArgs zedFileExtensions}; do
      run ${pkgs.duti}/bin/duti -s dev.zed.Zed ".$extension" all
    done
  '';
}
