#!/usr/bin/env bash
# Host-side orchestration for kube-prometheus-stack

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
     RELEASE=$PROMETHEUS_RELEASE"
}
