#!/usr/bin/env bash
# Setting up cni plugin on both conrtol-plane and worker nodes
# This script will need to be executed directly on the host
set -Eeuo pipefail

# Arguments to feed before injecting script into the nodes
VERSION="${VERSION:-}"
URL="${URL:-}"

# Hard coded args
COMPONENT="cni-plugins"
BIN_DIR="/opt/cni/bin"
FILE="$(basename "$URL")"

is_installed() {
  [[ -x "$BIN_DIR/bridge" ]]
}

install() {
  curl -fsSLO "$URL"
  sudo mkdir -p "$BIN_DIR"
  sudo tar -C "$BIN_DIR" -xzf "$FILE"
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main