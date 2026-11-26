{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "multica-cli";
  version = "0.12.1";

  src = fetchurl {
    url = "https://github.com/multica-ai/multica/releases/download/v${finalAttrs.version}/multica-cli-${finalAttrs.version}-linux-amd64.tar.gz";
    hash = "sha256-c97a5hIdKRVJCZec4DcUkSsNzlW77uC34nQVq+hfEr0=";
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 multica "$out/bin/multica"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/multica" --version
  '';

  meta = {
    mainProgram = "multica";
    platforms = [ "x86_64-linux" ];
  };
})
