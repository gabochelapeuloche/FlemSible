#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="kubeconfig"

KUBECONFIG_SRC="/etc/kubernetes/admin.conf"
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_DST="$KUBECONFIG_DIR/config"

verify() {
  [[ -f "$KUBECONFIG_DST" ]] \
    || { echo "❌ kubeconfig not found"; exit 1; }

  kubectl version --client >/dev/null \
    || { echo "❌ kubectl client not working"; exit 1; }

  kubectl cluster-info >/dev/null \
    || { echo "❌ cannot reach cluster via kubeconfig"; exit 1; }
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"