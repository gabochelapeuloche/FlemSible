#!/usr/bin/env bash

: '
Virtual infrastructure management using Multipass
'

configure_vm() {
  local VM="$1"

  case "$VM" in
    "$CP_PREFIX"-*)
      configure_firewall "$VM" "cp" "$CNI"
      ;;
    "$W_PREFIX"-*)
      configure_firewall "$VM" "worker" "$CNI"
      ;;
  esac
}

create_vms() {
  VMS=()

  for ((i=1; i<=CP_NUMBER; i++)); do
    VMS+=("$CP_PREFIX-$i")
  done

  for ((i=1; i<=W_NUMBER; i++)); do
    VMS+=("$W_PREFIX-$i")
  done

  log "Creating VMs:"
  for vm in "${VMS[@]}"; do
    log "  - $vm"
  done

  for VM in "${VMS[@]}"; do
    multipass info "$VM" &>/dev/null && die "La VM $VM existe déjà"
  done

  # Create all VMs first
  for VM in "${VMS[@]}"; do
    multipass launch "$OS_VERSION" \
      --name "$VM" \
      --cpus "$CPUS" \
      --memory "$MEMORY" \
      --disk "$DISK"
  done

  # Configure firewall in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM" &
  done
  wait
}