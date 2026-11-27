{
  assetName,
  writeShellApplication,
  coreutils,
  curl,
  jq,
}:
writeShellApplication {
  name = "ensure-magpie-cli";
  runtimeEnv.MAGPIE_ASSET_NAME = assetName;
  runtimeInputs = [
    coreutils
    curl
    jq
  ];
  text = builtins.readFile ./ensure.sh;
}
