{
  linux = {
    architectures = [
      "aarch64"
      "x86_64"
    ];
    home = ./home.nix;
  };
  darwin = {
    architectures = [ "aarch64" ];
    home = ./home.nix;
  };
}
