#!/usr/bin/env bash
# Host-side orchestration for Envoy Gateway

install_envoy() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing Envoy Gateway $ENVOY_CHART_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/envoy.sh" \
    "CHART_VERSION=$ENVOY_CHART_VERSION \
     REPO_URL=$ENVOY_REPO_URL \
     NAMESPACE=$ENVOY_NAMESPACE \
     RELEASE=$ENVOY_RELEASE"
}
