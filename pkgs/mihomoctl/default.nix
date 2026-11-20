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
  sudoPath ? "/usr/bin/sudo",
  systemctlPath ? "/usr/bin/systemctl",
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
      sudoPath
      systemctlPath
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
  !platform.isLinux || builtins.match "[a-zA-Z0-9_.@:-]+\\.service" serviceName != null
) "mihomoctl：Linux 上需要指定单个已存在的 .service 单元名。";
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
    printf '%s\n' ${lib.escapeShellArg settings} > "$appDir/settings.json"
    makeWrapper ${pythonPath} "$out/bin/mihomoctl" --add-flag -I --add-flag "$appDir"
  ''
