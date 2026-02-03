#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="calico"
CALICO_VERSION="3.28.0"

OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"
CUSTOM_RESOURCES_URL="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

CALICO_NS="calico-system"

verify() {
  echo "[$COMPONENT] verifying calico pods"

  # Namespace
  kubectl get ns "$CALICO_NS" >/dev/null

  # All calico-node pods running
  kubectl get pods -n "$CALICO_NS" -l k8s-app=calico-node \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}' \
    | grep -vqv "Running" && {
      echo "❌ some calico-node pods are not Running"
      exit 1
    }

  # No calico pod in bad state
  kubectl get pods -n "$CALICO_NS" \
    --field-selector=status.phase!=Running,status.phase!=Succeeded \
    | grep -q . && {
      echo "❌ some calico pods are not healthy"
      kubectl get pods -n "$CALICO_NS"
      exit 1
    }

  # One calico-node per node
  local nodes pods
  nodes=$(kubectl get nodes --no-headers | wc -l)
  pods=$(kubectl get pods -n "$CALICO_NS" -l k8s-app=calico-node --no-headers | wc -l)

  [[ "$nodes" -eq "$pods" ]] || {
    echo "❌ calico-node pods ($pods) != nodes ($nodes)"
    exit 1
  }
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"