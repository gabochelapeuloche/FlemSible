#!/usr/bin/env bash
# Host-side orchestration for ArgoCD

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
     RELEASE=$ARGOCD_RELEASE"
}
