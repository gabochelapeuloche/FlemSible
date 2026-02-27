# Setting up iptables parameters on both conrtol-plane and worker nodes
# This script will need to be executed directly on the host

#!/usr/bin/env bash

export_kubeconfig_to_host() {
  local CP_NODE="${CP_PREFIX}-1"
  local OUT="$SCRIPT_DIR/kubeconfig/$CLUSTER_NAME.conf"

  mkdir -p "$(dirname "$OUT")"

  # rendre le kubeconfig accessible
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf
  multipass exec "$CP_NODE" -- sudo chown ubuntu:ubuntu /tmp/admin.conf

  # transfert vers l'hôte
  multipass transfer "$CP_NODE:/tmp/admin.conf" "$OUT"

  # nettoyage
  multipass exec "$CP_NODE" -- rm -f /tmp/admin.conf

  # corriger l'IP si nécessaire
  local CP_IP
  CP_IP=$(multipass info "$CP_NODE" | awk '/IPv4/ {print $2; exit}')

  sed -i "s|server: https://.*:6443|server: https://$CP_IP:6443|" "$OUT"

  chmod 600 "$OUT"

  log "kubeconfig exported to $OUT"
}