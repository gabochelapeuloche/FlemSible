#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/host-config.sh — Kubeconfig export to host.
#
# Copies the cluster admin kubeconfig from the control-plane VM to the host
# machine, rewrites the server address from the internal VM IP to the
# Multipass-reachable IP, and renames the context for clarity.
# Sets KUBECONFIG in the current shell session so kubectl works immediately.
#
# Sourced by: main.sh (runs on the host, not injected into a VM)
# Globals consumed: CP_PREFIX, SCRIPT_DIR
# Globals written:  KUBECONFIG (exported)
# =============================================================================

# export_kubeconfig_to_host
# Pull admin.conf from the control-plane VM, rewrite the server IP, rename
# the context, and export KUBECONFIG for the current shell session.
# Globals: CP_PREFIX (r), SCRIPT_DIR (r)
export_kubeconfig_to_host() {
  local CP_NODE="${CP_PREFIX}-1"
  local CLUSTER_NAME="k8s-cluster"
  local OUT="$SCRIPT_DIR/kubeconfig/${CLUSTER_NAME}.conf"
  mkdir -p "$(dirname "$OUT")"

  print_cue "Exporting kubeconfig from $CP_NODE..."

  # Temp copy with readable permissions so multipass transfer can pull it
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf
  multipass exec "$CP_NODE" -- sudo chown ubuntu:ubuntu /tmp/admin.conf

  multipass transfer "$CP_NODE:/tmp/admin.conf" "$OUT"

  # Clean up the temp file from the VM
  multipass exec "$CP_NODE" -- rm -f /tmp/admin.conf

  # kubeadm advertises the internal VM IP; replace with the Multipass-visible IP
  local CP_IP
  CP_IP=$(multipass info "$CP_NODE" | awk '/IPv4/ {print $2; exit}')
  sed -i "s|server: https://.*:6443|server: https://$CP_IP:6443|g" "$OUT"

  # Rename context from the generic kubeadm default to something descriptive
  kubectl config --kubeconfig="$OUT" \
    rename-context "kubernetes-admin@kubernetes" "multipass-k8s" 2>/dev/null || true

  chmod 600 "$OUT"
  export KUBECONFIG="$OUT"

  echo "✅ Kubeconfig exported to $OUT"
}
