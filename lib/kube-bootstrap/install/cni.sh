#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="cni-plugins"
VERSION="1.5.0"
BIN_DIR="/opt/cni/bin"

is_installed() {
  [[ -x "$BIN_DIR/bridge" ]]
}

install() {
  curl -fsSLO "https://github.com/containernetworking/plugins/releases/download/v${VERSION}/cni-plugins-linux-amd64-v${VERSION}.tgz"
  sudo mkdir -p "$BIN_DIR"
  sudo tar -C "$BIN_DIR" -xzf "cni-plugins-linux-amd64-v${VERSION}.tgz"
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main