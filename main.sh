#!/usr/bin/env bash
set -Eeuo pipefail

: '
  Main file of the script orchestrating the setup of a virtual kubernetes cluster on
  ubuntu machines using multipass
'

####
## Requirements en script variables
####

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/virtual-infrastructure/network-rules.sh"
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"
source "$SCRIPT_DIR/tests/virtual-infrastructure/network.sh"
source "$SCRIPT_DIR"/lib/kube-bootstrap/install/host-config.sh

require_cmd multipass

####
## Multipass VMS setup
####

log "\nusers customization\n"

section "user custom"

user_inputs "$@"

validate_config

section "Cluster configuration"
log "Control-plane number : $CP_NUMBER"
log "Workers number       : $W_NUMBER"
log "CP prefix            : $CP_PREFIX"
log "Worker prefix        : $W_PREFIX"
log "OS version           : $OS_VERSION"
log "CPUs                 : $CPUS"
log "Memory               : $MEMORY"
log "Disk                 : $DISK"

section "creation des vms"

create_vms

section "Preparing nodes"
for NODE in "${VMS[@]}"; do
  prepare_node "$NODE" &
done
wait

# section "Verifying virtual infra network"
# for NODE in "${VMS[@]}"; do
#   # verify_node_networking "$NODE" &
# done
# wait


####
## Kubernetes Bootstrap
####

section "Kubernetes bootstrap"
sleep 1

init_control_plane
sleep 1

export_kubeconfig_to_host
mkdir -p ~/.kube
cp kubeconfig/test.conf ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes
sleep 1

join_workers
sleep 1

install_calico_operator
kubectl get nodes -o wide
section "Cluster ready 🎉"