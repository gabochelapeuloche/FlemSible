#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/prometheus.sh — kube-prometheus-stack install.
#
# Installs the kube-prometheus-stack Helm chart on the control-plane node.
# This includes Prometheus, Alertmanager, and Grafana as a single release.
# --wait is set with a 10-minute timeout to handle slow cluster scheduling.
#
# Runs on:  control-plane-1 only
# Injected: CHART_VERSION, REPO_URL, REPO_NAME, CHART, NAMESPACE, RELEASE
# =============================================================================
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
CHART="${CHART:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
COMPONENT="kube-prometheus-stack"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if the prometheus Helm release is already deployed, 1 otherwise.
is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

# install
# Add the prometheus-community Helm repo and deploy the kube-prometheus-stack chart.
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
