#!/usr/bin/env bash
# Install Harbor registry via Helm on the control-plane node
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
CHART="${CHART:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
EXTERNAL_URL="${EXTERNAL_URL:-}"
COMPONENT="harbor"

export KUBECONFIG=/etc/kubernetes/admin.conf

is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

install() {
  echo "[$COMPONENT] adding Helm repo $REPO_NAME → $REPO_URL"
  helm repo add "$REPO_NAME" "$REPO_URL"
  helm repo update

  echo "[$COMPONENT] installing chart $CHART v$CHART_VERSION"
  helm install "$RELEASE" "$CHART" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION" \
    --set expose.type=nodePort \
    --set expose.tls.enabled=false \
    --set externalURL="$EXTERNAL_URL" \
    --set persistence.enabled=false \
    --wait \
    --timeout 10m

  echo ""
  echo "[$COMPONENT] Harbor portal : $EXTERNAL_URL"
  echo "[$COMPONENT] Default login : admin / Harbor12345"
  echo "[$COMPONENT] Change the password immediately after first login."
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
