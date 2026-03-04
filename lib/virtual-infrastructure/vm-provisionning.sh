# Virtual infrastructure bootstrap, creating each vm needed for 
# each node and performing common tunning for control-plane and
# workers

#!/usr/bin/env bash

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
    sleep 2 &
  done
  wait

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

  # Configure firewall in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM" &
    sleep 2
  done
  wait
}

configure_vm() {
  # functions that calls the function for vm firewall config
  # and passes if vm is worker or control-plane

  local VM="$1"

  case "$VM" in
    "$CP_PREFIX"-*)
      configure_firewall "$VM" "cp" "$CNI"
      ;;
    "$W_PREFIX"-*)
      configure_firewall "$VM" "worker" "$CNI"
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