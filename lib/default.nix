{ lib }:

let
  moduleRegistry = {
    "base/core" = ../modules/base/core/default.nix;
    "base/gui" = ../modules/base/gui/default.nix;
    "darwin/core" = ../modules/darwin/core/default.nix;
    "darwin/gui" = ../modules/darwin/gui/default.nix;
    "linux/core" = ../modules/linux/core/default.nix;
    "linux/gui" = ../modules/linux/gui/default.nix;
  };

  allowedModules = builtins.attrNames moduleRegistry;

  mkAutoImports =
    {
      dir,
      exclude ? [ "default.nix" ],
    }:
    let
      entries = builtins.readDir dir;
      validFiles = lib.filterAttrs (
        name: type:
        (type == "regular" && lib.hasSuffix ".nix" name && !(builtins.elem name exclude))
        || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
      ) entries;
    in
    map (name: dir + "/${name}") (lib.attrNames validFiles);

  mkHost =
    {
      system,
      username,
      email,
      gitName,
      gpgKey ? null,
      modules ? [
        "base/core"
      ],
    }@host:
    let
      isStr = builtins.isString;
      validModules = lib.all (group: builtins.elem group allowedModules) modules;
      baseRequired = lib.all (v: v) [
        (isStr system)
        (isStr username)
        (isStr email)
        (isStr gitName)
      ];
    in
    assert lib.assertMsg baseRequired "mkHost: system/username/email/gitName must be strings.";
    assert lib.assertMsg (gpgKey == null || isStr gpgKey) "mkHost: gpgKey must be null or string.";
    assert lib.assertMsg validModules "mkHost: modules contains unsupported value.";
    host;
in
{
  inherit
    mkAutoImports
    mkHost
    allowedModules
    moduleRegistry
    ;
}
