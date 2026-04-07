#!/usr/bin/env bash
# Install Istio (base + istiod) via Helm on the control-plane node
set -Eeuo pipefail

VERSION="${VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
NAMESPACE="${NAMESPACE:-}"
COMPONENT="istio"

export KUBECONFIG=/etc/kubernetes/admin.conf

is_installed() {
  helm status istiod -n "$NAMESPACE" >/dev/null 2>&1
}

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
