#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/istio.sh — Host-side orchestration for Istio.
#
# Provides install_istio, which deploys Istio (istio-base + istiod) via Helm
# on the control-plane node. Istio must be installed before any other service
# that relies on sidecar injection (e.g., Envoy Gateway).
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, ISTIO_*, SCRIPT_DIR
# =============================================================================

# install_istio
# Deploy Istio via Helm on the control-plane node.
# Installs two charts sequentially: istio-base then istiod.
# Globals: CP_PREFIX (r), ISTIO_VERSION (r), ISTIO_REPO_URL (r),
#          ISTIO_REPO_NAME (r), ISTIO_NAMESPACE (r), SCRIPT_DIR (r)
install_istio() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing Istio $ISTIO_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/istio.sh" \
    "VERSION=$ISTIO_VERSION \
     REPO_URL=$ISTIO_REPO_URL \
     REPO_NAME=$ISTIO_REPO_NAME \
     NAMESPACE=$ISTIO_NAMESPACE" \
    "$LOG_SESSION_DIR/istio.log"
}
