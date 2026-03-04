# Main file of the script orchestrating the setup of a virtual kubernetes cluster on
# ubuntu machines using multipass
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Nettoyage automatique en cas d'erreur
trap 'echo "An error occurred. Check logs."; exit 1' ERR

source "$SCRIPT_DIR/lib/utils.sh"
# source "$SCRIPT_DIR/lib/virtual-infrastructure/injections/network-rules.sh"
source "$SCRIPT_DIR/lib/virtual-infrastructure/vm-provisionning.sh"
source "$SCRIPT_DIR/lib/kube-bootstrap/node-bootstrap.sh"
source "$SCRIPT_DIR/lib/kube-bootstrap/injections/host-config.sh"
require_cmd multipass

LOG_SESSION_DIR="$SCRIPT_DIR/logs/run_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_SESSION_DIR"
export LOG_SESSION_DIR

# 1. Setup
section "Setting up"
user_inputs "$@"
get_version_info "${K8S_VERSION:-1.35}"
validate_config

# Virtual layer creation
section "Creation des vms"
create_vms && sleep 1

# 3. Provisioning (Parallèle sur tous les nœuds)
section "🛠 Preparing nodes"
for NODE in "${VMS[@]}"; do
  prepare_node "$NODE" &
done
wait
sleep 1

# 4. K8s Orchestration (Séquentiel car logique métier)
section "☸️  Initializing Cluster"
init_control_plane
export_kubeconfig_to_host

# Joining workers
section "🤝 Joining Workers"
join_workers && sleep 1

# Calico bootstraping
section "🌐 Installing Network Plugin"
install_calico_operator

# 5. Final Check
until kubectl get nodes | grep -q "Ready"; do
    echo -n "." && sleep 2
done
section "Cluster ready 🎉"