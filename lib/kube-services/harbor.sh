#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/harbor.sh — Host-side orchestration for Helm and Harbor.
#
# Provides install_helm and install_harbor functions called from main.sh.
# Each function delegates to an injection script that runs on the control-plane
# via run_on_node_env.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, HELM_*, HARBOR_*, SCRIPT_DIR
# =============================================================================

# install_helm
# Install the Helm CLI on the control-plane node.
# Required before any Helm-based service can be deployed.
# Globals: CP_PREFIX (r), HELM_VERSION (r), HELM_URL (r), SCRIPT_DIR (r)
install_helm() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing Helm v$HELM_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/helm.sh" \
    "VERSION=$HELM_VERSION URL=$HELM_URL"
}

# install_harbor
# Deploy Harbor via Helm on the control-plane as a NodePort service on :30002.
# Globals: CP_PREFIX (r), HARBOR_* (r), SCRIPT_DIR (r)
install_harbor() {
  local CP_NODE="${CP_PREFIX}-1"
  local CP_IP
  CP_IP=$(multipass info "$CP_NODE" | awk '/IPv4/ {print $2; exit}')

  print_cue "Installing Harbor $HARBOR_CHART_VERSION on $CP_NODE (http://$CP_IP:30002)"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/harbor.sh" \
    "CHART_VERSION=$HARBOR_CHART_VERSION \
     REPO_URL=$HARBOR_REPO_URL \
     REPO_NAME=$HARBOR_REPO_NAME \
     CHART=$HARBOR_CHART \
     NAMESPACE=$HARBOR_NAMESPACE \
     RELEASE=$HARBOR_RELEASE \
     EXTERNAL_URL=http://$CP_IP:30002"
}
