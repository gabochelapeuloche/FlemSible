#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/argocd.sh — ArgoCD install via Helm.
#
# Installs ArgoCD on the control-plane node using the official Helm chart.
# Configures insecure mode (HTTP) and exposes the UI as a NodePort on :30090.
# Prints the generated admin password after install — change it immediately.
#
# Runs on:  control-plane-1 only
# Injected: CHART_VERSION, REPO_URL, REPO_NAME, CHART, NAMESPACE, RELEASE
# =============================================================================
set -Eeuo pipefail

CHART_VERSION="${CHART_VERSION:-}"
REPO_URL="${REPO_URL:-}"
REPO_NAME="${REPO_NAME:-}"
CHART="${CHART:-}"
NAMESPACE="${NAMESPACE:-}"
RELEASE="${RELEASE:-}"
COMPONENT="argocd"

export KUBECONFIG=/etc/kubernetes/admin.conf

# is_installed
# Return 0 if the ArgoCD Helm release is already deployed, 1 otherwise.
is_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

# install
# Add the ArgoCD Helm repo, deploy the chart on NodePort :30090, then print
# the generated admin password from the initial admin secret.
install() {
  echo "[$COMPONENT] adding Helm repo $REPO_NAME → $REPO_URL"
  helm repo add "$REPO_NAME" "$REPO_URL"
  helm repo update

  echo "[$COMPONENT] installing chart $CHART v$CHART_VERSION"
  helm install "$RELEASE" "$CHART" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION" \
    --set configs.params."server\.insecure"=true \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30090 \
    --wait \
    --timeout 10m

  ADMIN_PASSWORD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)
  echo ""
  echo "[$COMPONENT] UI available on port 30090 of any node"
  echo "[$COMPONENT] Login: admin / $ADMIN_PASSWORD"
  echo "[$COMPONENT] Change the password immediately after first login."
}

main() {
  is_installed || install
  echo "[$COMPONENT] ready"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
