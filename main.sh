#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"

log "\nusers customization\n"

### Users customizations
user_inputs $#

log "\ncreation des vms\n"
log "control-plane number: $CP_NUMBER"
log "workers number: $W_NUMBER"
log "control-plane prefix: $CP_PREFIX"
log "worker prefix: $W_PREFIX"
log "os version: $OS_VERSION"
log "number of cpus: $CPUS"
log "memory allocation: $MEMORY"
log "disk allocation: $DISK"

# Création  des vms
require_cmd multipass

create_vms

for NODE in "${VMS[@]}"; do
  prepare_node "$NODE"
done

init_control_plane
join_workers

# for NODE in "${VMS[@]}"; do
#   init_control_plane
# done

# for NODE in "${VMS[@]}"; do
#   join_workers
# done