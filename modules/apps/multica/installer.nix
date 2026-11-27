{
  assetPlatform,
  writeShellApplication,
  coreutils,
  curl,
  gnutar,
  gzip,
  jq,
}:
writeShellApplication {
  name = "ensure-multica-cli";
  runtimeEnv.MULTICA_ASSET_PLATFORM = assetPlatform;
  runtimeInputs = [
    coreutils
    curl
    gnutar
    gzip
    jq
  ];
  text = ''
    bin_dir="$HOME/.local/bin"
    cli="$bin_dir/multica"
    if [[ -L "$cli" ]]; then
      echo "无法更新 Multica：$cli 是符号链接。" >&2
      exit 1
    fi
    if [[ -e "$cli" ]]; then
      if [[ ! -f "$cli" || ! -x "$cli" ]]; then
        echo "无法更新 Multica：$cli 不是可执行的普通文件。" >&2
        exit 1
      fi
      if ! "$cli" update; then
        "$cli" --version
        echo "Multica 更新失败，已保留现有版本。" >&2
      fi
      exit 0
    fi

    mkdir -p "$bin_dir"
    tmp=$(mktemp -d "$bin_dir/.multica-install.XXXXXXXX")
    trap 'rm -rf -- "$tmp"' EXIT
    fetch() {
      curl -q --fail --silent --show-error --location --proto '=https' \
        --connect-timeout 10 --max-time 120 "$@"
    }
    fetch https://api.github.com/repos/multica-ai/multica/releases/latest > "$tmp/release.json"
    asset=$(jq -er --arg platform "$MULTICA_ASSET_PLATFORM" '
      (.tag_name | ltrimstr("v")) as $version |
      .assets[] | select(.name == "multica-cli-\($version)-\($platform).tar.gz") |
      select(.digest | test("^sha256:[a-f0-9]{64}$")) |
      [.browser_download_url, (.digest | ltrimstr("sha256:"))] | @tsv
    ' "$tmp/release.json")
    IFS=$'\t' read -r url digest <<< "$asset"
    fetch "$url" > "$tmp/archive"
    (cd "$tmp" && printf '%s  archive\n' "$digest" | sha256sum --check --quiet)
    tar -xzOf "$tmp/archive" multica > "$tmp/multica"
    chmod 755 "$tmp/multica"
    "$tmp/multica" --version
    mv -T -- "$tmp/multica" "$cli"
  '';
}
