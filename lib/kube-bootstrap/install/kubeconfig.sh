#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="kubeconfig"
KUBECONFIG_SRC="/etc/kubernetes/admin.conf"
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_DST="$KUBECONFIG_DIR/config"

  # mkdir -p ~/.kube
  # multipass exec "$NODE_NAME" -- sudo mkdir -p /root/.kube
  # multipass exec "$NODE_NAME" -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config
  # multipass exec "$NODE_NAME" -- sudo cp /etc/kubernetes/admin.conf /root/.kube/config
  # chmod 600 ~/.kube/config

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

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"