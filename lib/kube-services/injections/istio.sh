#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/istio.sh — Istio service mesh install via Helm.
#
# Installs Istio in two sequential Helm releases: istio-base (CRDs and cluster
# roles) followed by istiod (the control plane). Both must be in the same
# version. Istio must be installed before any service mesh-dependent workload.
#
# Runs on:  control-plane-1 only
# Injected: VERSION, REPO_URL, REPO_NAME, NAMESPACE
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
NAMESPACE="${NAMESPACE:-}"
COMPONENT="istio"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if istiod is already deployed in the target namespace, 1 otherwise.
is_installed() {
  helm status istiod -n "$NAMESPACE" >/dev/null 2>&1
}

# install
# Add the Istio Helm repo and install istio-base then istiod sequentially.
# istio-base must complete before istiod — they cannot be parallelized.
install() {
  echo "[$COMPONENT] adding Helm repo $REPO_NAME → $REPO_URL"
  helm repo add "$REPO_NAME" "$REPO_URL"
  helm repo update

  echo "[$COMPONENT] installing istio-base v$VERSION"
  helm install istio-base "$REPO_NAME/base" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$VERSION" \
    --wait

  echo "[$COMPONENT] installing istiod v$VERSION"
  helm install istiod "$REPO_NAME/istiod" \
    --namespace "$NAMESPACE" \
    --version "$VERSION" \
    --wait \
    --timeout 10m
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
