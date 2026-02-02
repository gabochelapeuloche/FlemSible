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
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"

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

####
## Kubernetes Bootstrap
####

section "Kubernetes bootstrap"
init_control_plane
join_workers
install_calico_operator

kubectl get nodes -o wide
section "Cluster ready 🎉"