{ ... }:

{
  # 核心模块装配在 flake.nix 中按主机的 settings.modules 动态完成。
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
