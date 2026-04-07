#!/usr/bin/env bash
# Install Helm CLI on a node
set -Eeuo pipefail

VERSION="${VERSION:-}"
URL="${URL:-}"
COMPONENT="helm"

is_installed() {
  command -v helm >/dev/null 2>&1 && helm version --short 2>/dev/null | grep -q "v${VERSION}"
}

install() {
  echo "[$COMPONENT] installing v$VERSION"

  local archive="helm-v${VERSION}-linux-amd64.tar.gz"
  curl -fsSLO "$URL"
  tar -zxf "$archive" linux-amd64/helm
  sudo install -m 755 linux-amd64/helm /usr/local/bin/helm
  rm -rf linux-amd64 "$archive"
}

main() {
  is_installed || install
  echo "[$COMPONENT] $(helm version --short 2>/dev/null)"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
