#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/helm.sh — Helm CLI installation.
#
# Downloads the Helm tarball, extracts the binary, and installs it to
# /usr/local/bin. Runs on the control-plane node only — Helm is used there
# to deploy all optional services (Harbor, Prometheus, ArgoCD, etc.).
#
# Runs on:  control-plane-1 only
# Injected: VERSION, URL (tarball download URL)
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
URL="${URL:-}"

COMPONENT="helm"

# is_installed
# Return 0 if helm is in PATH at the expected version, 1 otherwise.
is_installed() {
  command -v helm >/dev/null 2>&1 \
    && helm version --short 2>/dev/null | grep -q "v${VERSION}"
}

# install
# Download the Helm tarball, extract the binary, and install it system-wide.
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
