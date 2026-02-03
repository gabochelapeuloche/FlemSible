#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="kubeconfig"

KUBECONFIG_SRC="/etc/kubernetes/admin.conf"
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_DST="$KUBECONFIG_DIR/config"

is_installed() {
  [[ -f "$KUBECONFIG_DST" ]] || return 1
  kubectl config view >/dev/null 2>&1
}

install() {
  echo "[$COMPONENT] installing kubeconfig for current user"

  [[ -f "$KUBECONFIG_SRC" ]] \
    || { echo "❌ $KUBECONFIG_SRC not found"; exit 1; }

  mkdir -p "$KUBECONFIG_DIR"

  sudo cp "$KUBECONFIG_SRC" "$KUBECONFIG_DST"
  sudo chown "$(id -u):$(id -g)" "$KUBECONFIG_DST"
  chmod 600 "$KUBECONFIG_DST"
}

verify() {
  [[ -f "$KUBECONFIG_DST" ]] \
    || { echo "❌ kubeconfig not found"; exit 1; }

  kubectl version --client >/dev/null \
    || { echo "❌ kubectl client not working"; exit 1; }

  kubectl cluster-info >/dev/null \
    || { echo "❌ cannot reach cluster via kubeconfig"; exit 1; }
}

main() {
  is_installed || install
  # verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"