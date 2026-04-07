#!/usr/bin/env bash
# Virtual infrastructure bootstrap, creating each vm needed for 
# each node and performing common tunning for control-plane and
# workers

create_vms() {
  # function that creates vms control-planes and workers

  # Use pre-baked base image when available, otherwise fall back to the OS alias
  local CP_IMAGE W_IMAGE
  if [[ -n "${BASE_IMAGE:-}" ]]; then
    CP_IMAGE="file://$BASE_IMAGE"
    W_IMAGE="file://$BASE_IMAGE"
  else
    CP_IMAGE="$CP_OS_VERSION"
    W_IMAGE="$W_OS_VERSION"
  fi

  for ((i=1; i<=CP_NUMBER; i++)); do
    VMS+=("$CP_PREFIX-$i")
    multipass info "$CP_PREFIX-$i" &>/dev/null && die "La VM $CP_PREFIX-$i existe déjà"
    multipass launch "$CP_IMAGE" \
      --name "$CP_PREFIX-$i" \
      --cpus "$CP_CPUS" \
      --memory "$CP_MEMORY" \
      --disk "$CP_DISK"
  done

  for ((i=1; i<=W_NUMBER; i++)); do
    VMS+=("$W_PREFIX-$i")
    multipass info "$W_PREFIX-$i" &>/dev/null && die "La VM $W_PREFIX-$i existe déjà"
    multipass launch "$W_IMAGE" \
      --name "$W_PREFIX-$i" \
      --cpus "$W_CPUS" \
      --memory "$W_MEMORY" \
      --disk "$W_DISK"
  done

  # Configure all vms in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM" &
  done
  wait
}

configure_vm() {
  # functions that calls the function for vm firewall config
  # and passes if vm is worker or control-plane
  local VM="$1"

  case "$VM" in
    "$CP_PREFIX"-*)
      run_on_node_env "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/network-rules.sh"\
      "VM=$VM NODE_PORTS_ARRAY='$CP_OPEN_PORTS' CNI_PORTS_ARRAY='$CALICO_OPEN_PORTS'"
      ;;
    "$W_PREFIX"-*)
      run_on_node_env "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/network-rules.sh"\
      "VM=$VM NODE_PORTS_ARRAY='$W_OPEN_PORTS' CNI_PORTS_ARRAY='$CALICO_OPEN_PORTS'"
      ;;
  esac

  if [[ -z "${BASE_IMAGE:-}" ]]; then
    # No pre-baked image — apply kernel/system config
    for script in disable-swap ipv4-forward iptables; do
      run_on_node "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/$script.sh" &
    done
    wait
  fi
}