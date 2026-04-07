#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/kubeadm-init.sh — Control-plane initialisation.
#
# Runs kubeadm init on the control-plane node. Only executed on the first
# control-plane VM via run_on_node_env. Idempotent: skips if the cluster
# is already initialised (admin.conf present and API server responding).
#
# Runs on:  control-plane-1 only
# Injected: POD_CIDR
# =============================================================================
set -Eeuo pipefail

POD_CIDR="${POD_CIDR:-}"

COMPONENT="init-cp"

export KUBECONFIG=/etc/kubernetes/admin.conf
export PAGER=cat
export KUBECTL_PAGER=cat

# is_installed
# Return 0 if the cluster is already initialised (admin.conf exists and the
# API server is responding), 1 otherwise.
is_installed() {
  [[ -f /etc/kubernetes/admin.conf ]] \
    && sudo kubectl get nodes --kubeconfig=/etc/kubernetes/admin.conf &>/dev/null
}

# install
# Run kubeadm init with the injected POD_CIDR and the node's primary IP.
install() {
  local CP_IP NODE_NAME
  NODE_NAME="$(hostname)"
  CP_IP="$(hostname -I | awk '{print $1}')"

  echo "[$COMPONENT] initializing Kubernetes control-plane on $CP_IP"

  [[ -n "$CP_IP" ]]    || { echo "❌ CP_IP could not be determined"; exit 1; }
  [[ -n "$POD_CIDR" ]] || { echo "❌ POD_CIDR was not injected by the host"; exit 1; }

  sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --node-name "$NODE_NAME"
}

main() {
  if is_installed; then
    echo "[$COMPONENT] cluster already initialized — skipping"
  else
    install
  fi
  echo "[$COMPONENT] done"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
