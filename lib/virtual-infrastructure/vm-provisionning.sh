#!/usr/bin/env bash
# =============================================================================
# lib/virtual-infrastructure/vm-provisionning.sh — VM lifecycle management.
#
# Responsible for launching Multipass VMs and applying per-role configuration.
# VMs are launched sequentially to avoid host resource spikes. Configuration
# (firewall rules, kernel settings) runs in parallel across all VMs after launch.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, CP_NUMBER, CP_OS_VERSION, CP_CPUS, CP_MEMORY,
#                   CP_DISK, W_PREFIX, W_NUMBER, W_OS_VERSION, W_CPUS,
#                   W_MEMORY, W_DISK, BASE_IMAGE, SCRIPT_DIR
# Globals written:  VMS (array of all launched VM names)
# =============================================================================

# create_vms
# Launch all control-plane and worker VMs sequentially, then configure each
# in parallel. Populates the global VMS array consumed by main.sh and
# node-bootstrap.sh.
# Globals: VMS (w), BASE_IMAGE (r), CP_* (r), W_* (r)
create_vms() {
  local CP_IMAGE W_IMAGE

  # Validate base image path before attempting launch to give a clear error
  if [[ -n "${BASE_IMAGE:-}" ]]; then
    [[ -f "$BASE_IMAGE" ]] \
      || die "Base image not found: $BASE_IMAGE — run tools/build-base-image.sh first"
    CP_IMAGE="file://$BASE_IMAGE"
    W_IMAGE="file://$BASE_IMAGE"
  else
    CP_IMAGE="$CP_OS_VERSION"
    W_IMAGE="$W_OS_VERSION"
  fi

  _launch_vm() {
    local NAME="$1" IMAGE="$2" CPUS="$3" MEMORY="$4" DISK="$5"
    VMS+=("$NAME")
    if [[ "${DRY_RUN:-false}" != "true" ]] && multipass info "$NAME" &>/dev/null; then
      printf "  %-20s \e[33m[reusing existing VM]\e[0m\n" "$NAME"
    else
      drun multipass launch "$IMAGE" \
        --name "$NAME" --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK"
    fi
  }

  for ((i=1; i<=CP_NUMBER; i++)); do
    _launch_vm "$CP_PREFIX-$i" "$CP_IMAGE" "$CP_CPUS" "$CP_MEMORY" "$CP_DISK"
  done

  for ((i=1; i<=W_NUMBER; i++)); do
    _launch_vm "$W_PREFIX-$i" "$W_IMAGE" "$W_CPUS" "$W_MEMORY" "$W_DISK"
  done

  # Configuration is role-specific but independent per VM — run in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM" &
  done
  wait
}

# configure_vm [vm_name]
# Apply role-specific firewall rules and (when no base image) kernel/system
# settings to a single VM. Matches the VM name prefix to determine its role.
# Arguments: $1 = VM name (e.g. control-plane-1, worker-2)
# Globals: CP_PREFIX (r), W_PREFIX (r), BASE_IMAGE (r), SCRIPT_DIR (r)
configure_vm() {
  local VM="$1"

  # Apply role-specific firewall rules — always runs regardless of base image
  case "$VM" in
    "$CP_PREFIX"-*)
      run_on_node_env "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/network-rules.sh" \
        "VM=$VM NODE_PORTS_ARRAY='$CP_OPEN_PORTS' CNI_PORTS_ARRAY='$CALICO_OPEN_PORTS'"
      ;;
    "$W_PREFIX"-*)
      run_on_node_env "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/network-rules.sh" \
        "VM=$VM NODE_PORTS_ARRAY='$W_OPEN_PORTS' CNI_PORTS_ARRAY='$CALICO_OPEN_PORTS'"
      ;;
  esac

  if [[ -z "${BASE_IMAGE:-}" ]]; then
    # No pre-baked image — apply kernel/system config (baked into base image otherwise)
    for script in disable-swap ipv4-forward iptables; do
      run_on_node "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/$script.sh" &
    done
    wait
  fi
}
