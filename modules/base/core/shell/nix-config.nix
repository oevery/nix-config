{
  githubAccessTokensSnippet = ''
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      access_tokens="github.com=$(gh auth token)"
      if [ -n "''${NIX_CONFIG-}" ]; then
        export NIX_CONFIG="$NIX_CONFIG
access-tokens = $access_tokens"
      else
        export NIX_CONFIG="access-tokens = $access_tokens"
      fi
    fi
  '';
}
