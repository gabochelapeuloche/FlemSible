#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/harbor.sh — Harbor container registry install.
#
# Installs Harbor via Helm on the control-plane node, exposed as a NodePort
# service on port 30002. The external URL is injected by the host-side
# orchestrator so Harbor's self-referencing links point to the right address.
#
# Runs on:  control-plane-1 only
# Injected: CHART_VERSION, REPO_URL, REPO_NAME, CHART, NAMESPACE, RELEASE,
#           EXTERNAL_URL
# =============================================================================
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
CHART="${CHART:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
EXTERNAL_URL="${EXTERNAL_URL:-}"
COMPONENT="harbor"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if the Harbor Helm release is already deployed, 1 otherwise.
is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

# install
# Add the Harbor Helm repo and deploy the chart with NodePort and external URL.
install() {
  echo "[$COMPONENT] adding Helm repo $REPO_NAME → $REPO_URL"
  helm repo add "$REPO_NAME" "$REPO_URL"
  helm repo update

  echo "[$COMPONENT] installing chart $CHART v$CHART_VERSION"
  helm install "$RELEASE" "$CHART" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION" \
    --set expose.type=nodePort \
    --set expose.nodePort.ports.http.nodePort=30002 \
    --set expose.tls.enabled=false \
    --set externalURL="$EXTERNAL_URL" \
    --wait \
    --timeout 20m
}

main() {
  is_installed || install
  echo "[$COMPONENT] UI → $EXTERNAL_URL  (admin / Harbor12345)"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
