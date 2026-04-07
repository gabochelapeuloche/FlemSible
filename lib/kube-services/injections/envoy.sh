#!/usr/bin/env bash
# Install Envoy Gateway via Helm (OCI) on the control-plane node
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
COMPONENT="envoy-gateway"

export KUBECONFIG=/etc/kubernetes/admin.conf

is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

install() {
  # OCI-based chart — no repo add needed
  echo "[$COMPONENT] installing $REPO_URL v$CHART_VERSION"
  helm install "$RELEASE" "$REPO_URL" \
    --version "v$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 10m
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
