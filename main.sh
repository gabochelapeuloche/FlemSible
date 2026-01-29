#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"

log "\nusers customization\n"

### Users customizations
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --cp-number)
      CP_NUMBER="$2"
      if ! is_number "$CP_NUMBER"; then
        echo "CP_NUMBER doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --w-number)
      W_NUMBER="$2"
      if ! is_number "$W_NUMBER"; then
        echo "W_NUMBER doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      if ! is_number "$CPUS"; then
        echo "CPUS doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      if ! is_storage "$MEMORY"; then
        echo "MEMORY doit être de la forme XG avec X un entier positif"
        exit 1
      fi
      shift 2
      ;;
    --disk)
      DISK="$2"
      if ! is_number "$DISK"; then
        echo "DISK doit être de la forme XG avec X un entier positif"
        exit 1
      fi
      shift 2
      ;;
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Option inconnue : $1"
      exit 1
    ;;
  esac
done

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

# init_control_plane
# join_workers