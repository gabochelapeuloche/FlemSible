export_kubeconfig_to_host() {
  local CP_NODE="${CP_PREFIX}-1"
  local CLUSTER_NAME="k8s-cluster" # Correction : pas de $ ici
  local OUT="$SCRIPT_DIR/kubeconfig/${CLUSTER_NAME}.conf"

  log "Exporting kubeconfig from $CP_NODE to host..."

  mkdir -p "$(dirname "$OUT")"

  # 1. Préparation sur la VM (copie temporaire pour gérer les droits)
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf
  multipass exec "$CP_NODE" -- sudo chown ubuntu:ubuntu /tmp/admin.conf

  # 2. Transfert vers l'hôte
  multipass transfer "$CP_NODE:/tmp/admin.conf" "$OUT"

  # 3. Nettoyage immédiat sur la VM
  multipass exec "$CP_NODE" -- rm -f /tmp/admin.conf

  # 4. Correction de l'IP : kubeadm met l'IP interne, l'hôte a besoin de l'IP Multipass
  local CP_IP
  CP_IP=$(multipass info "$CP_NODE" | awk '/IPv4/ {print $2; exit}')
  
  # On utilise | comme délimiteur sed pour la sécurité
  sed -i "s|server: https://.*:6443|server: https://$CP_IP:6443|g" "$OUT"
  chmod 600 "$OUT"
  
  log "✅ Kubeconfig exported to $OUT and KUBECONFIG env var set."

  # 1. On s'assure que le dossier .kube existe
  mkdir -p $HOME/.kube

  # 2. On sauvegarde l'ancien config s'il existe
  [ -f $HOME/.kube/config ] && cp $HOME/.kube/config $HOME/.kube/config.bak

  # 3. On fusionne et on définit le nouveau config comme étant le défaut
  KUBECONFIG=$HOME/.kube/config:$OUT kubectl config view --flatten > $HOME/.kube/config_new
  mv $HOME/.kube/config_new $HOME/.kube/config
  kubectl config rename-context "kubernetes-admin@kubernetes" "multipass-k8s"
  kubectl config use-context multipass-k8s
}