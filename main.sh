# Main file of the script orchestrating the setup of a virtual kubernetes cluster on
# ubuntu machines using multipass
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VMS=()

cleanup() {
  [[ ${#VMS[@]} -eq 0 ]] && return
  echo ""
  echo "❌ Error — purging ${#VMS[@]} VM(s): ${VMS[*]}"
  for VM in "${VMS[@]}"; do
    multipass delete "$VM" --purge 2>/dev/null \
      && echo "  deleted $VM" \
      || echo "  $VM not found, skipping"
  done
}

trap 'echo "An error occurred. Check logs."; cleanup; exit 1' ERR

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/virtual-infrastructure/vm-provisionning.sh"
source "$SCRIPT_DIR/lib/kube-bootstrap/node-bootstrap.sh"
source "$SCRIPT_DIR/lib/kube-bootstrap/injections/host-config.sh"
source "$SCRIPT_DIR/lib/kube-services/harbor.sh"
source "$SCRIPT_DIR/lib/kube-services/prometheus.sh"
source "$SCRIPT_DIR/lib/kube-services/argocd.sh"
source "$SCRIPT_DIR/lib/kube-services/istio.sh"
source "$SCRIPT_DIR/lib/kube-services/envoy.sh"
require_cmd multipass

LOG_SESSION_DIR="$SCRIPT_DIR/logs/run_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_SESSION_DIR"
export LOG_SESSION_DIR

# Setup
user_inputs "$@"
get_version_info "${K8S_VERSION:-1.35_base}"
validate_config

# Virtual layer creation
section "VMs Spin Up"
create_vms

# Provisioning (Parallelisme on each nodes)
section "🛠 Preparing Nodes"
for NODE in "${VMS[@]}"; do
  prepare_node "$NODE" &
done
wait

# K8s Orchestration
section "☸️  Initializing Cluster"
init_control_plane
export_kubeconfig_to_host

# Joining workers
section "🤝 Joining Workers"
join_workers

# Helm CLI (required before any Helm-based service)
[[ "$TOOL_HELM" == "true" ]] && { section "⎈  Installing Helm"; install_helm; }

# Calico bootstraping
section "🌐 Installing Network Plugin"
install_calico_operator

all_nodes_ready() {
  local statuses
  statuses=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}')
  [[ -n "$statuses" ]] && ! echo "$statuses" | grep -qv "Ready"
}

calico_ready() {
  local statuses
  statuses=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | awk '{print $3}')
  [[ -n "$statuses" ]] && ! echo "$statuses" | grep -qv "Running"
}

# Wait for all nodes Ready, then Calico pods Running before installing services
section "⏳ Waiting for cluster"
until all_nodes_ready;  do echo -n "." && sleep 3; done; echo
until calico_ready;     do echo -n "." && sleep 3; done; echo

section "Cluster ready 🎉"
kubectl get nodes

# Optional services
# Istio first — mesh infrastructure must be up before services that may use sidecars
[[ "$TOOL_ISTIO" == "true" ]] && { section "🕸️  Installing Istio"; install_istio; }

# Remaining services are independent — install in parallel
section "🛠 Installing services"
[[ "$TOOL_HARBOR" == "true" ]]     && install_harbor &
[[ "$TOOL_PROMETHEUS" == "true" ]] && install_prometheus &
[[ "$TOOL_ARGOCD" == "true" ]]     && install_argocd &
[[ "$TOOL_ENVOY" == "true" ]]      && install_envoy &
wait

print_total_time
echo ""
echo "To access the cluster, run:"
echo "  export KUBECONFIG=$SCRIPT_DIR/kubeconfig/k8s-cluster.conf"