{ lib, ... }:

let
  mkDockerComposePlugin = ''
    if command -v brew >/dev/null 2>&1; then
      compose_prefix="$(brew --prefix docker-compose 2>/dev/null || true)"

      if [ -n "$compose_prefix" ] && [ -x "$compose_prefix/bin/docker-compose" ]; then
        mkdir -p "$HOME/.docker/cli-plugins"
        ln -sfn "$compose_prefix/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
      fi
    fi
  '';
in
{
  home.activation.ensureDockerComposePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] mkDockerComposePlugin;
}
