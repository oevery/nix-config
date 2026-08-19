{ pkgs, darwinName }:

pkgs.writeShellApplication {
  name = "brewup";

  runtimeInputs = with pkgs; [
    coreutils
    gh
    gnugrep
    jq
    perl
  ];

  text = ''
    set -eu

    flake_path="$HOME/.config/home-manager"
    flake_file="$flake_path/flake.nix"
    lock_file="$flake_path/flake.lock"
    darwin_name=${pkgs.lib.escapeShellArg darwinName}

    if ! gh auth status >/dev/null 2>&1; then
      printf '%s\n' 'brewup: gh authentication is required' >&2
      exit 1
    fi
    if ! command -v nix >/dev/null 2>&1; then
      printf '%s\n' 'brewup: nix command not found' >&2
      exit 127
    fi
    if [ ! -f "$flake_file" ] || [ ! -f "$lock_file" ]; then
      printf '%s\n' "brewup: missing flake files under $flake_path" >&2
      exit 1
    fi

    current_version=$(jq -r '.nodes["brew-src"].original.ref // empty' "$lock_file")
    latest_version=$(gh api repos/Homebrew/brew/releases/latest --jq '.tag_name')

    if ! printf '%s\n' "$current_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      printf '%s\n' "brewup: invalid current Homebrew version: $current_version" >&2
      exit 1
    fi
    if ! printf '%s\n' "$latest_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      printf '%s\n' "brewup: invalid latest Homebrew release: $latest_version" >&2
      exit 1
    fi
    if [ "$current_version" = "$latest_version" ]; then
      printf '%s\n' "Homebrew is already up to date: $current_version"
      exit 0
    fi

    current_url="github:Homebrew/brew/$current_version"
    latest_url="github:Homebrew/brew/$latest_version"
    match_count=$(grep -Fo "$current_url" "$flake_file" | wc -l | tr -d ' ')
    if [ "$match_count" -ne 1 ]; then
      printf '%s\n' "brewup: expected exactly one $current_url reference in $flake_file" >&2
      exit 1
    fi

    backup_dir=$(mktemp -d "''${TMPDIR:-/tmp}/brewup.XXXXXX")
    cp "$flake_file" "$backup_dir/flake.nix"
    cp "$lock_file" "$backup_dir/flake.lock"
    update_succeeded=0
    cleanup() {
      status=$?
      trap - EXIT
      if [ "$update_succeeded" -ne 1 ]; then
        cp "$backup_dir/flake.nix" "$flake_file"
        cp "$backup_dir/flake.lock" "$lock_file"
        printf '%s\n' 'brewup: update failed; restored flake.nix and flake.lock' >&2
      fi
      rm -rf "$backup_dir"
      exit "$status"
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    BREWUP_CURRENT_URL="$current_url" BREWUP_LATEST_URL="$latest_url" \
      perl -0pi -e 's/\Q$ENV{BREWUP_CURRENT_URL}\E/$ENV{BREWUP_LATEST_URL}/g' "$flake_file"

    access_tokens="github.com=$(gh auth token)"
    if [ -n "''${NIX_CONFIG-}" ]; then
      export NIX_CONFIG="$NIX_CONFIG
    access-tokens = $access_tokens"
    else
      export NIX_CONFIG="access-tokens = $access_tokens"
    fi

    nix flake update brew-src --flake "$flake_path"
    nix flake check --no-build --all-systems --no-write-lock-file "$flake_path"
    nix build --no-link --no-write-lock-file \
      "$flake_path#darwinConfigurations.$darwin_name.config.system.build.toplevel"

    update_succeeded=1
    printf '%s\n' "Homebrew updated and verified: $current_version -> $latest_version"
  '';
}
