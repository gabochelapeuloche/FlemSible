

#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/k8s-setup.conf"

[[ -f "$CONFIG_FILE" ]] || {
  echo "❌ missing config file $CONFIG_FILE"
  exit 1
}

source "$CONFIG_FILE"

export KUBECONFIG=/etc/kubernetes/admin.conf
export PAGER=cat
export KUBECTL_PAGER=cat

COMPONENT="init-cp"
NODE_NAME="$(hostname)"
CP_IP="$(hostname -I | awk '{print $1}')"
POD_CIDR="$POD_CIDR"

KUBECONFIG="/etc/kubernetes/admin.conf"

is_installed() {
  kubectl get pods -n kube-system \
    | grep kube-apiserver | grep -q Running
}

install() {
  echo "[$COMPONENT] initializing Kubernetes control-plane"

  [[ -n "$CP_IP" ]] || { echo "❌ CP_IP is not set"; exit 1; }

  sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --node-name "$NODE_NAME" \
    --ignore-preflight-errors=all
    &> /tmp/kubeadm-init.log
  
  # kubectl --kubeconfig=/etc/kubernetes/admin.conf
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"