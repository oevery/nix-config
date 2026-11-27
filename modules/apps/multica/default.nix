let
  assets.x86_64 = "linux-amd64";
in
{
  linux = {
    architectures = builtins.attrNames assets;
    home = import ./linux.nix assets;
  };
}
