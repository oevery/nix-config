{ inputs, pkgs, lib, host, configurationRevision, ... }:
{
  home.packages = [ (pkgs.callPackage ./package.nix {
    controller = if builtins.elem "apps/mihomo" host.modules then
      (import ../mihomo/packages.nix { inherit inputs lib pkgs; }).ctl else null;
  }) ];
  home.extraBuilderCommands = lib.optionalString (pkgs.stdenv.isLinux && configurationRevision != null) ''
    printf '%s\n' ${lib.escapeShellArg configurationRevision} > "$out/hmops-revision"
  '';
  xdg.configFile."hmops/host.json".text = builtins.toJSON {
    name = host.homeConfigurationName;
    system = pkgs.stdenv.hostPlatform.system;
    modules = builtins.filter (name: builtins.elem name [
      "apps/mihomo" "apps/multica" "apps/magpie" "apps/omp"
    ]) host.modules;
  };
}
