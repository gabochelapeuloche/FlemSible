#!/usr/bin/env bash

: '
  This file initialise all the virtual infrastructure that will support
  the kubernetes cluster
'

source "$SCRIPT_DIR/lib/ufw.sh"

# function that creates virtual machines for nodes
create_vms() {
  VMS=()

  for ((i=1; i<=CP_NUMBER; i++)); do
    VMS+=("$CP_PREFIX-$i")
  done

  for ((i=1; i<=W_NUMBER; i++)); do
    VMS+=("$W_PREFIX-$i")
  done

  log "\nCréation des VMs :"
  for vm in "${VMS[@]}"; do
    log "  - $vm"
  done

  for VM in "${VMS[@]}"; do
    if multipass info "$VM" &>/dev/null; then
      die "La VM $VM existe déjà"
    fi
  done

  for VM in "${VMS[@]}"; do
    multipass launch "$OS_VERSION" \
      --name "$VM" \
      --cpus "$CPUS" \
      --memory "$MEMORY" \
      --disk "$DISK"

    setup_ufw_common "$VM"

    if [[ "$VM" =~ $CP_PREFIX ]]; then
      setup_ufw_cp "$VM"
    fi

    if [[ "$VM" =~ $W_PREFIX ]]; then
      setup_ufw_worker "$VM"
    fi

    if [[ "$CNI" == "calico" ]]; then
      setup_ufw_calico "$VM"
    fi

  done
}