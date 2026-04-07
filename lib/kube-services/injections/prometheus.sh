#!/usr/bin/env bash
# Install kube-prometheus-stack via Helm on the control-plane node
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
CHART="${CHART:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
COMPONENT="kube-prometheus-stack"

export KUBECONFIG=/etc/kubernetes/admin.conf

is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

install() {
  echo "[$COMPONENT] adding Helm repo $REPO_NAME → $REPO_URL"
  helm repo add "$REPO_NAME" "$REPO_URL"
  helm repo update

  echo "[$COMPONENT] installing chart $CHART v$CHART_VERSION"
  helm install "$RELEASE" "$CHART" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION" \
    --wait \
    --timeout 10m
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
