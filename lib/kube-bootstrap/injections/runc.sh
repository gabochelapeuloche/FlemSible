#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/runc.sh — runc installation.
#
# Downloads the runc binary from the official GitHub release and installs it
# at /usr/local/sbin/runc. runc is the low-level OCI container runtime used
# by containerd. Baked into the base image — skipped at provision time when
# BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: VERSION, URL (binary download URL)
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
URL="${URL:-}"

COMPONENT="runc"
BIN_PATH="/usr/local/sbin/runc"

# is_installed
# Return 0 if runc binary already exists at BIN_PATH, 1 otherwise.
is_installed() {
  [[ -x "$BIN_PATH" ]]
}

# install
# Download the runc binary and install it with executable permissions.
install() {
  local ARCH
  ARCH=$(uname -m); [[ "$ARCH" == "aarch64" ]] && ARCH="arm64" || ARCH="amd64"
  local ARCH_URL="${URL/runc.amd64/runc.${ARCH}}"
  echo "[$COMPONENT] installing version $VERSION"
  curl -fsSLO "$ARCH_URL"
  sudo install -m 755 "runc.${ARCH}" "$BIN_PATH"
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
