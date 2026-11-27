let
  assets.x86_64 = "magpie-cli-linux-amd64";
in
{
  linux = {
    architectures = builtins.attrNames assets;
    home = import ./linux.nix assets;
  };
}
