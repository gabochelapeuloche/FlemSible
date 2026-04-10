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
ALERTMANAGER_MEM_REQUEST="${ALERTMANAGER_MEM_REQUEST:-64Mi}"
ALERTMANAGER_MEM_LIMIT="${ALERTMANAGER_MEM_LIMIT:-128Mi}"
PROMETHEUS_MEM_REQUEST="${PROMETHEUS_MEM_REQUEST:-256Mi}"
PROMETHEUS_MEM_LIMIT="${PROMETHEUS_MEM_LIMIT:-768Mi}"
GRAFANA_MEM_REQUEST="${GRAFANA_MEM_REQUEST:-64Mi}"
GRAFANA_MEM_LIMIT="${GRAFANA_MEM_LIMIT:-128Mi}"
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
    --timeout 10m \
    --set alertmanager.alertmanagerSpec.resources.requests.memory="$ALERTMANAGER_MEM_REQUEST" \
    --set alertmanager.alertmanagerSpec.resources.limits.memory="$ALERTMANAGER_MEM_LIMIT" \
    --set prometheus.prometheusSpec.resources.requests.memory="$PROMETHEUS_MEM_REQUEST" \
    --set prometheus.prometheusSpec.resources.limits.memory="$PROMETHEUS_MEM_LIMIT" \
    --set grafana.resources.requests.memory="$GRAFANA_MEM_REQUEST" \
    --set grafana.resources.limits.memory="$GRAFANA_MEM_LIMIT"
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
