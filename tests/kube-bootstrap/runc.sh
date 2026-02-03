#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="runc"
VERSION="1.1.12"
BIN_PATH="/usr/local/sbin/runc"
DOWNLOAD_URL="https://github.com/opencontainers/runc/releases/download/v${VERSION}/runc.amd64"

verify() {
  "$BIN_PATH" --version | grep -q "runc version $VERSION"
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"