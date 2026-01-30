#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"

log "\nusers customization\n"
require_cmd multipass

### Users customizations
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

section "Kubernetes bootstrap"
init_control_plane
join_workers
install_calico_operator

kubectl get nodes -o wide
section "Cluster ready 🎉"