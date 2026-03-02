#!/usr/bin/env bash
set -Eeuo pipefail

POD_CIDR="$CP_POD_CIDR"
export KUBECONFIG=/etc/kubernetes/admin.conf
export PAGER=cat
export KUBECTL_PAGER=cat
COMPONENT="init-cp"
NODE_NAME="$(hostname)"
CP_IP="$(hostname -I | awk '{print $1}')"

is_installed() {
  # On vérifie si l'api-server est déjà là pour éviter de ré-initialiser
  [[ -f /etc/kubernetes/admin.conf ]] && sudo kubectl get nodes --kubeconfig=/etc/kubernetes/admin.conf &>/dev/null
}

install() {
  echo "[$COMPONENT] initializing Kubernetes control-plane on $CP_IP"

  [[ -n "$CP_IP" ]] || { echo "❌ CP_IP is not set"; exit 1; }
  [[ "$POD_CIDR" != "JSONVALUE" ]] || { echo "❌ POD_CIDR non injecté par l'hôte"; exit 1; }

  sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --node-name "$NODE_NAME" \
    --ignore-preflight-errors=all \
    # | tee /tmp/kubeadm-init.log # 'tee' permet de voir le log dans ton fichier de log hôte aussi
}

main() {
  if is_installed; then
    echo "[$COMPONENT] cluster already initialized"
  else
    install
  fi
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"