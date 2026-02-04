#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="calico"
CALICO_VERSION="3.28.0"
OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"
CUSTOM_RESOURCES_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"
CALICO_NS="calico-system"

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