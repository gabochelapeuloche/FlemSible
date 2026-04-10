#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/argocd.sh — Host-side orchestration for ArgoCD.
#
# Provides install_argocd, which deploys ArgoCD via Helm on the control-plane
# node by delegating to the node-side injection script.
# ArgoCD is exposed on NodePort :30090 with insecure HTTP mode enabled.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, ARGOCD_*, SCRIPT_DIR
# =============================================================================

# install_argocd
# Deploy ArgoCD via Helm on the control-plane node.
# The injection script prints the generated admin password after install.
# Globals: CP_PREFIX (r), ARGOCD_CHART_VERSION (r), ARGOCD_REPO_URL (r),
#          ARGOCD_REPO_NAME (r), ARGOCD_CHART (r),
#          ARGOCD_NAMESPACE (r), ARGOCD_RELEASE (r), SCRIPT_DIR (r)
install_argocd() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing ArgoCD $ARGOCD_CHART_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/argocd.sh" \
    "CHART_VERSION=$ARGOCD_CHART_VERSION \
     REPO_URL=$ARGOCD_REPO_URL \
     REPO_NAME=$ARGOCD_REPO_NAME \
     CHART=$ARGOCD_CHART \
     NAMESPACE=$ARGOCD_NAMESPACE \
     RELEASE=$ARGOCD_RELEASE" \
    "$LOG_SESSION_DIR/argocd.log"
}
