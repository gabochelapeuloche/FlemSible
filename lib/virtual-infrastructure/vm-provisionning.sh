#!/usr/bin/env bash
# Virtual infrastructure bootstrap, creating each vm needed for 
# each node and performing common tunning for control-plane and
# workers

create_vms() {
  # function that creates vms control-planes and workers

  for ((i=1; i<=CP_NUMBER; i++)); do
    VMS+=("$CP_PREFIX-$i")

    multipass info "$CP_PREFIX-$i" &>/dev/null && die "La VM $CP_PREFIX-$i existe déjà"
    
    multipass launch "$CP_OS_VERSION" \
      --name "$CP_PREFIX-$i" \
      --cpus "$CP_CPUS" \
      --memory "$CP_MEMORY" \
      --disk "$CP_DISK"
    sleep 2
  done
  

  for ((i=1; i<=W_NUMBER; i++)); do
    VMS+=("$W_PREFIX-$i")
    
    multipass info "$W_PREFIX-$i" &>/dev/null && die "La VM $W_PREFIX-$i existe déjà"

    multipass launch "$CP_OS_VERSION" \
      --name "$W_PREFIX-$i" \
      --cpus "$W_CPUS" \
      --memory "$W_MEMORY" \
      --disk "$W_DISK"
    sleep 2
  done
  

  # Configure vms in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM"
    sleep 2
  done
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

  for script in \
    disable-swap \
    ipv4-forward \
    iptables
  do
    run_on_node "$VM" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/$script.sh"
    sleep 1
  done
}