#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/envoy.sh — Envoy Gateway install via Helm OCI.
#
# Installs Envoy Gateway from an OCI Helm chart registry. Unlike traditional
# charts, no `helm repo add` step is needed — the chart URL is an OCI reference
# used directly as the chart argument to `helm install`.
#
# Runs on:  control-plane-1 only
# Injected: CHART_VERSION, REPO_URL (OCI chart reference), NAMESPACE, RELEASE
# =============================================================================
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
COMPONENT="envoy-gateway"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if the Envoy Gateway Helm release is already deployed, 1 otherwise.
is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

# install
# Install Envoy Gateway directly from the OCI chart URL — no repo add required.
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
