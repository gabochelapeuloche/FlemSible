#!/usr/bin/env bash

: '
  This file contains script for preparing the virtual machines to receive a node (master
  or control-plane)
'

# Function that runs on every node to do the common setup
prepare_node() {
  local NODE="$1"

  log "Preparing node $NODE"

  for script in \
    disable-swap \
    ipv4-forward \
    iptables \
    containerd \
    runc \
    cni \
    kube \
    crictl-containerd
  do
    # log "  → $script"
    run_on_node "$NODE" "$SCRIPT_DIR/lib/kube-bootstrap/install/$script.sh"
  done
}

# Function that initialize control-plane nodes
init_control_plane() {
  NODE_NAME="${CP_PREFIX}-1"
  CP_IP=$(multipass exec "$NODE_NAME" -- hostname -I | awk '{print $1}')

  log "Initializing control-plane on $NODE_NAME ($CP_IP)"

  run_on_node "$NODE_NAME" \
    "$SCRIPT_DIR/lib/kube-bootstrap/install/init-cp.sh"

  run_on_node "$NODE_NAME" \
    "$SCRIPT_DIR/lib/kube-bootstrap/install/kubeconfig.sh"
}

join_workers() {
  CP_NODE="$CP_PREFIX-1"

  JOIN_CMD=$(multipass exec "$CP_NODE" -- sudo kubeadm token create --print-join-command)
  
  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    log "Joining worker $NODE"
    multipass exec "$NODE" -- sudo bash -c "$JOIN_CMD"
  done
}

install_calico_operator() {
  local CP_NODE="${CP_PREFIX}-1"

  log "Installing Calico (Tigera Operator) on $CP_NODE"
  

  run_on_node "$NODE" "$SCRIPT_DIR/lib/kube-bootstrap/install/calico.sh"
  # multipass exec "$CP_NODE" -- sudo bash -c "
  #   $(< "$SCRIPT_DIR/lib/kubeadm-files/calico.sh")
  # "
}