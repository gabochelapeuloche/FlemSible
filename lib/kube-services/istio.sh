#!/usr/bin/env bash
# Host-side orchestration for Istio

install_istio() {
  local CP_NODE="${CP_PREFIX}-1"
  print_cue "Installing Istio $ISTIO_VERSION on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-services/injections/istio.sh" \
    "VERSION=$ISTIO_VERSION \
     REPO_URL=$ISTIO_REPO_URL \
     REPO_NAME=$ISTIO_REPO_NAME \
     NAMESPACE=$ISTIO_NAMESPACE"
}
