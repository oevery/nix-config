{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.isDarwin {
  # 在图形终端中隐藏登录提示信息。
  home.file.".hushlogin".text = "";
}
