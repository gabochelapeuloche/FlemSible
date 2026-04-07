#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/envoy.sh — Host-side orchestration for Envoy Gateway.
#
# Provides install_envoy, which deploys Envoy Gateway via Helm (OCI chart)
# on the control-plane node. No Helm repo add is required — the chart is
# referenced directly as an OCI URL.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, ENVOY_*, SCRIPT_DIR
# =============================================================================

# install_envoy
# Deploy Envoy Gateway via Helm OCI on the control-plane node.
# Globals: CP_PREFIX (r), ENVOY_CHART_VERSION (r), ENVOY_REPO_URL (r),
#          ENVOY_NAMESPACE (r), ENVOY_RELEASE (r), SCRIPT_DIR (r)
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
