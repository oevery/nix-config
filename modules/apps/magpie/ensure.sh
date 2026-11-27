bin_dir="$HOME/.local/bin"
cli="$bin_dir/magpie"
if [[ -L "$cli" || ( -e "$cli" && ! -f "$cli" ) ]]; then
  echo "无法管理 Magpie：$cli 是符号链接或不是普通文件。" >&2
  exit 1
fi

if [[ ! -e "$cli" ]]; then
  mkdir -p "$bin_dir"
  tmp=$(mktemp -d "$bin_dir/.magpie-install.XXXXXXXX")
  trap 'rm -rf -- "$tmp"' EXIT
  fetch() {
    curl -qfsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 120 "$@"
  }
  fetch 'https://usemagpie.ai/api/latest?channel=daily' > "$tmp/feed"
  asset=$(jq -er --arg name "$MAGPIE_ASSET_NAME" '
    select(.channel == "daily") | .assets[$name] |
    select((.url | startswith("https://")) and (.sha256 | test("^[0-9a-f]{64}$"))) |
    [.url, .sha256] | @tsv
  ' "$tmp/feed")
  IFS=$'\t' read -r url digest <<< "$asset"
  fetch "$url" > "$tmp/magpie"
  (cd "$tmp" && printf '%s  magpie\n' "$digest" | sha256sum --check --quiet)
  chmod 755 "$tmp/magpie"
  "$tmp/magpie" --version
  mv -T -- "$tmp/magpie" "$cli"
  first_install=true
else
  "$cli" --version
  first_install=false
fi

"$cli" update auto off
"$cli" update channel daily
if [[ "$first_install" == false ]] && ! "$cli" update; then
  "$cli" --version
  echo "Magpie 更新失败，已安装的版本仍可运行。" >&2
fi
