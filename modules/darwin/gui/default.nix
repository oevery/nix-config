{ myLib, ... }:

{
  imports = myLib.mkAutoImports {
    dir = ./.;
    exclude = [
      # OrbStack 自带 Docker Compose 支持，旧 Homebrew 插件软链模块保留但不引入。
      "docker-compose-plugin.nix"
    ];
  };
}
