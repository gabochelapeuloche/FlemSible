# Performing calico installation on the control-plane node
# This script will need to be executed directly on the host

#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="calico"
CALICO_NS="calico-system"

# Arguments to feed before injecting script into the nodes
CALICO_VERSION="JSONVALUE"
OPERATOR_URL="JSONVALUE"
CUSTOM_RESOURCES_URL="JSONVALUE"

is_installed() {
  kubectl get ns "$CALICO_NS" >/dev/null 2>&1
}

install() {
  echo "[$COMPONENT] installing Tigera Operator"
  
  export KUBECONFIG=/etc/kubernetes/admin.conf
  
  kubectl create -f "$OPERATOR_URL" || true
  kubectl rollout status deployment/tigera-operator \
    -n tigera-operator \
    --timeout=120s

  kubectl apply -f "$CUSTOM_RESOURCES_URL"
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"