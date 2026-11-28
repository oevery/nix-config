{
  linux = {
    architectures = [ "x86_64" "aarch64" ];
    home = ./linux.nix;
  };
  darwin = {
    architectures = [ "aarch64" ];
    darwin = ./darwin.nix;
  };
}
