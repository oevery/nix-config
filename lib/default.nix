{ lib }:

let
  homeGroups = {
    "base/core" = ../modules/base/core/default.nix;
    "base/gui" = ../modules/base/gui/default.nix;
    "darwin/core" = ../modules/darwin/core/default.nix;
    "darwin/gui" = ../modules/darwin/gui/default.nix;
    "linux/core" = ../modules/linux/core/default.nix;
    "linux/gui" = ../modules/linux/gui/default.nix;
  };

  apps = {
    "apps/hmops" = ../modules/apps/hmops;
    "apps/magpie" = ../modules/apps/magpie;
    "apps/mihomo" = ../modules/apps/mihomo;
    "apps/multica" = ../modules/apps/multica;
    "apps/omp" = ../modules/apps/omp;
  };
  moduleRegistry =
    lib.mapAttrs (_: path: _: { home = path; }) homeGroups
    // lib.mapAttrs (
      name: path: system:
      let
        parts = builtins.match "([^-]+)-([^-]+)" system;
        unsupported = throw "${name} 暂不支持 ${system}";
        platform = (import path).${builtins.elemAt parts 1} or unsupported;
      in
      if parts != null && builtins.elem (builtins.head parts) platform.architectures then
        platform
      else
        unsupported
    ) apps;
  allowedModules = builtins.attrNames moduleRegistry;
  resolveHostModules =
    settings: layer:
    let
      entries = map (name: moduleRegistry.${name} settings.system) settings.modules;
    in
    map (entry: entry.${layer}) (builtins.filter (builtins.hasAttr layer) entries);

  mkAutoImports =
    {
      dir,
      exclude ? [ ],
    }:
    let
      excluded = [ "default.nix" ] ++ exclude;
      entries = builtins.readDir dir;
      validFiles = lib.filterAttrs (
        name: type:
        !(builtins.elem name excluded)
        && (
          (type == "regular" && lib.hasSuffix ".nix" name)
          || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
        )
      ) entries;
    in
    map (name: dir + "/${name}") (lib.attrNames validFiles);

  mkHost =
    {
      system,
      homeConfigurationName,
      username,
      email,
      gitName,
      modules ? [
        "base/core"
      ],
      ...
    }@host:
    let
      isStr = builtins.isString;
      unknownModules = builtins.filter (name: !(builtins.elem name allowedModules)) modules;
      baseRequired = lib.all (v: v) [
        (isStr system)
        (isStr homeConfigurationName)
        (isStr username)
        (isStr email)
        (isStr gitName)
      ];
    in
    assert lib.assertMsg baseRequired
      "mkHost：system、homeConfigurationName、username、email 和 gitName 必须是字符串。";
    assert lib.assertMsg (unknownModules == [ ]) "未知模块：${lib.concatStringsSep "、" unknownModules}";
    host;
in
{
  inherit
    mkAutoImports
    mkHost
    allowedModules
    moduleRegistry
    resolveHostModules
    ;
}
