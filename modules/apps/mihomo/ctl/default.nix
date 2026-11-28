{
  curl,
  lib,
  makeWrapper,
  python3,
  runCommand,
  stdenv,
  mihomoPath,
  serviceName,
  stateDir,
  configFile,
  controlDir ? stateDir,
  placeholderPath ? null,
  logDir ? "/Library/Logs/Mihomo",
  runMarker ? null,
  sudoPath ? "/usr/bin/sudo",
  systemctlPath ? "/usr/bin/systemctl",
  validationUnit ? null,
}:

let
  platform = stdenv.hostPlatform;
  backend =
    if platform.isDarwin then
      ./launchd.py
    else if platform.isLinux then
      ./systemd.py
    else
      throw "mihomoctl：仅支持 Darwin 和 Linux。";
  python = python3.withPackages (packages: [ packages.pyyaml ]);
  pythonPath = lib.getExe' python "python3";
  settings = builtins.toJSON {
    inherit
      mihomoPath
      serviceName
      stateDir
      configFile
      controlDir
      placeholderPath
      logDir
      runMarker
      sudoPath
      systemctlPath
      validationUnit
      pythonPath
      ;
    curlPath = lib.getExe curl;
  };
in
assert lib.assertMsg (lib.all (lib.hasPrefix "/") [
  mihomoPath
  stateDir
  configFile
  controlDir
  sudoPath
  systemctlPath
]) "mihomoctl：运行路径必须是绝对路径。";
assert lib.assertMsg (
  !platform.isLinux || (serviceName == "mihomo.service" && validationUnit != null)
) "mihomoctl：Linux 需要 mihomo.service 和配套的校验 unit。";
runCommand "mihomoctl"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta.mainProgram = "mihomoctl";
  }
  ''
    appDir="$out/libexec/mihomoctl"
    mkdir -p "$appDir" "$out/bin"
    cp ${./mihomoctl.py} "$appDir/__main__.py"
    cp ${backend} "$appDir/backend.py"
    cp ${./errors.py} "$appDir/errors.py"
    cp ${./paths.py} "$appDir/paths.py"
    cp ${./subscriptions.py} "$appDir/subscriptions.py"
    cp ${./logs.py} "$appDir/logs.py"
    printf '%s\n' ${lib.escapeShellArg settings} > "$appDir/settings.json"
    makeWrapper ${pythonPath} "$out/bin/mihomoctl" --add-flag -I --add-flag "$appDir"
  ''
