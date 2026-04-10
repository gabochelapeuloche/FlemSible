#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/cni.sh — CNI plugins installation.
#
# Downloads and installs the standard CNI plugins (bridge, loopback, host-local,
# etc.) to /opt/cni/bin. These are the low-level network plugins used by
# containerd and required by Calico. Baked into the base image — skipped at
# provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: VERSION, URL (tarball download URL)
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
URL="${URL:-}"

COMPONENT="cni-plugins"
BIN_DIR="/opt/cni/bin"
ARCH=$(uname -m); [[ "$ARCH" == "aarch64" ]] && ARCH="arm64" || ARCH="amd64"
URL="${URL/linux-amd64/linux-${ARCH}}"
FILE="$(basename "$URL")"

# is_installed
# Return 0 if the bridge CNI plugin binary exists, 1 otherwise.
is_installed() {
  [[ -x "$BIN_DIR/bridge" ]]
}

# install
# Download the CNI plugins tarball and extract all binaries to BIN_DIR.
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
