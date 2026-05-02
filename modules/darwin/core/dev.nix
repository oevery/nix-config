{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cocoapods # iOS 依赖管理（Darwin 专用）
  ];
}
