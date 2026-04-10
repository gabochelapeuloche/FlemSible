#!/usr/bin/env bash
# =============================================================================
# main.sh — FlemSible entry point.
#
# Orchestrates a full Kubernetes cluster spin-up on Multipass VMs:
#   1. Parse user inputs and load version config from versions.json
#   2. Launch VMs (using pre-baked base image if configured)
#   3. Provision all nodes in parallel (system, runtime, k8s tools)
#   4. Bootstrap the control-plane (kubeadm init, kubeconfig export)
#   5. Join worker nodes in parallel
#   6. Install Calico CNI and wait for cluster readiness
#   7. Install optional services (Helm, Harbor, Prometheus, ArgoCD, Istio, Envoy)
#
# On any error the ERR trap fires cleanup(), which purges all VMs tracked in
# the VMS array to avoid leaving orphaned Multipass instances.
#
# Usage:
#   ./main.sh [K8S_VERSION_KEY] [--workers N] [--cpus N] [--memory Ng]
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VMS tracks every VM created during this run, used by cleanup() on ERR.
VMS=()

# cleanup
# Purge all VMs created during this run.
# Called automatically by the ERR trap — not intended for direct use.
# Globals: VMS (r)
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

# all_nodes_ready
# Return 0 when every node in the cluster reports Ready status, 1 otherwise.
# Used to gate service installs until the cluster is fully functional.
# Globals: KUBECONFIG (r, set by export_kubeconfig_to_host)
all_nodes_ready() {
  local statuses
  statuses=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}')
  [[ -n "$statuses" ]] && ! echo "$statuses" | grep -qv "Ready"
}

# calico_ready
# Return 0 when all pods in calico-system are Running, 1 otherwise.
# Calico must be fully operational before installing mesh-layer services.
# Globals: KUBECONFIG (r, set by export_kubeconfig_to_host)
calico_ready() {
  local statuses
  statuses=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | awk '{print $3}')
  [[ -n "$statuses" ]] && ! echo "$statuses" | grep -qv "Running"
}

# --- Setup ---
user_inputs "$@"
get_version_info "${K8S_VERSION:-1.35_base}"
validate_config

# --- Virtual layer ---
section "VMs Spin Up"
create_vms

# --- Node provisioning (parallel across all nodes) ---
section "Preparing Nodes"
for NODE in "${VMS[@]}"; do
  prepare_node "$NODE" &
done
wait

# --- Kubernetes bootstrap ---
section "Initializing Cluster"
init_control_plane
export_kubeconfig_to_host

section "Joining Workers"
join_workers

# Helm CLI must be installed before any Helm-based service can be deployed
[[ "$TOOL_HELM" == "true" ]] && { section "Installing Helm"; install_helm; }

# --- Network plugin ---
section "Installing Network Plugin"
install_calico_operator

# --- Cluster readiness gate ---
# All nodes must be Ready and all Calico pods Running before installing services.
# Services that start too early (before CNI is functional) will fail to schedule.
if [[ "${DRY_RUN:-false}" != "true" ]]; then
  section "Waiting for cluster"
  until all_nodes_ready;  do echo -n "." && sleep 3; done; echo
  until calico_ready;     do echo -n "." && sleep 3; done; echo

  section "Cluster ready"
  kubectl get nodes

  # Label worker nodes — kubeadm leaves the role column blank by default
  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "${CP_PREFIX}-"* ]] && continue
    kubectl label node "$NODE" node-role.kubernetes.io/worker=worker --overwrite \
      && echo "  labeled $NODE as worker"
  done
fi

# --- Optional services ---
# Istio first: mesh infrastructure must be up before sidecar-injected services
[[ "$TOOL_ISTIO" == "true" ]] && { section "Installing Istio"; install_istio; }

# Remaining services are independent — install in parallel
section "Installing services"
[[ "$TOOL_HARBOR" == "true" ]]     && install_harbor &
[[ "$TOOL_PROMETHEUS" == "true" ]] && install_prometheus &
[[ "$TOOL_ARGOCD" == "true" ]]     && install_argocd &
[[ "$TOOL_ENVOY" == "true" ]]      && install_envoy &
wait

print_total_time
echo ""
echo "To access the cluster, run:"
echo "  export KUBECONFIG=$SCRIPT_DIR/kubeconfig/k8s-cluster.conf"
