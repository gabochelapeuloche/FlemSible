# Performing calico installation on the control-plane node
# This script will need to be executed directly on the host

export_kubeconfig_to_host() {
  local CP_NODE="${CP_PREFIX}-1"
  local CLUSTER_NAME="k8s-cluster"
  local OUT="$SCRIPT_DIR/kubeconfig/${CLUSTER_NAME}.conf"
  mkdir -p "$(dirname "$OUT")"

  print_cue "Exporting kubeconfig from $CP_NODE..."

  # Setup on the vm. Temp copy for rights purpose
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf
  multipass exec "$CP_NODE" -- sudo chown ubuntu:ubuntu /tmp/admin.conf

  # Transfert to host
  multipass transfer "$CP_NODE:/tmp/admin.conf" "$OUT"

  # Cleaning
  multipass exec "$CP_NODE" -- rm -f /tmp/admin.conf

  # IP correction : kubeadm puts internal IP, the host need the multipass IP
  local CP_IP
  CP_IP=$(multipass info "$CP_NODE" | awk '/IPv4/ {print $2; exit}')
  sed -i "s|server: https://.*:6443|server: https://$CP_IP:6443|g" "$OUT"
    
  # Renaming the context inside the file
  kubectl config --kubeconfig="$OUT" rename-context "kubernetes-admin@kubernetes" "multipass-k8s" 2>/dev/null || true
  chmod 600 "$OUT"
    
  # Exporting the variable into the host (Will be true for the script only)
  export KUBECONFIG="$OUT"
    
  echo "✅ Kubeconfig exported to $OUT"
  echo "💡 Pour utiliser ce cluster : export KUBECONFIG=$OUT"
}