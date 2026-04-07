#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/calico.sh — Calico CNI installation.
#
# Deploys the Tigera operator via kubectl create, waits for it to be ready,
# then applies the Calico custom resources to trigger network plugin setup.
# Runs on the control-plane only — Calico pods are then scheduled by
# Kubernetes onto all nodes automatically.
#
# Runs on:  control-plane-1 only
# Injected: VERSION, OPERATOR_URL (manifest URL), CUSTOM_RESOURCES_URL
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
OPERATOR_URL="${OPERATOR_URL:-}"
CUSTOM_RESOURCES_URL="${CUSTOM_RESOURCES_URL:-}"

COMPONENT="calico"
CALICO_NS="calico-system"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if the calico-system namespace already exists, 1 otherwise.
is_installed() {
  kubectl get ns "$CALICO_NS" >/dev/null 2>&1
}

# install
# Apply the Tigera operator manifest, wait for its deployment to roll out,
# then apply the Calico custom resources.
install() {
  echo "[$COMPONENT] installing Tigera Operator"

  kubectl create -f "$OPERATOR_URL" || true
  kubectl rollout status deployment/tigera-operator \
    -n tigera-operator \
    --timeout=120s

  kubectl apply -f "$CUSTOM_RESOURCES_URL"
}

main() {
  is_installed || install
  echo "[$COMPONENT] [$VERSION] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
