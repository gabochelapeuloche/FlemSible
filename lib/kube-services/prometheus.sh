#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/prometheus.sh — Host-side orchestration for Prometheus.
#
# Provides install_prometheus, which deploys kube-prometheus-stack via Helm
# on the control-plane node by delegating to the node-side injection script.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, PROMETHEUS_*, SCRIPT_DIR
# =============================================================================

# install_prometheus
# Deploy kube-prometheus-stack via Helm on the control-plane node.
# Uses the prometheus injection script for the actual Helm install.
# Globals: CP_PREFIX (r), PROMETHEUS_CHART_VERSION (r), PROMETHEUS_REPO_URL (r),
#          PROMETHEUS_REPO_NAME (r), PROMETHEUS_CHART (r),
#          PROMETHEUS_NAMESPACE (r), PROMETHEUS_RELEASE (r), SCRIPT_DIR (r)
install_prometheus() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing kube-prometheus-stack $PROMETHEUS_CHART_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/prometheus.sh" \
    "CHART_VERSION=$PROMETHEUS_CHART_VERSION \
     REPO_URL=$PROMETHEUS_REPO_URL \
     REPO_NAME=$PROMETHEUS_REPO_NAME \
     CHART=$PROMETHEUS_CHART \
     NAMESPACE=$PROMETHEUS_NAMESPACE \
     RELEASE=$PROMETHEUS_RELEASE \
     ALERTMANAGER_MEM_REQUEST=$PROMETHEUS_ALERTMANAGER_MEM_REQUEST \
     ALERTMANAGER_MEM_LIMIT=$PROMETHEUS_ALERTMANAGER_MEM_LIMIT \
     PROMETHEUS_MEM_REQUEST=$PROMETHEUS_MEM_REQUEST \
     PROMETHEUS_MEM_LIMIT=$PROMETHEUS_MEM_LIMIT \
     GRAFANA_MEM_REQUEST=$PROMETHEUS_GRAFANA_MEM_REQUEST \
     GRAFANA_MEM_LIMIT=$PROMETHEUS_GRAFANA_MEM_LIMIT" \
    "$LOG_SESSION_DIR/prometheus.log"
}
