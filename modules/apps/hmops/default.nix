let
  userApp = architectures: { inherit architectures; home = ./home.nix; };
in
{
  linux = userApp [ "aarch64" "x86_64" ];
  darwin = userApp [ "aarch64" "x86_64" ];
}
