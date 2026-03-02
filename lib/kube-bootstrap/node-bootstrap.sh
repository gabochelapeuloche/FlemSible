#!/usr/bin/env bash

: '
  This file contains script for preparing the virtual machines to receive a node (master
  or control-plane)
'

prepare_node() {
  # Function that runs on every node to do the common setup
  local NODE="$1"
  
  log "Preparing node $NODE"

  log "Installing kubernetes components"

  for script in \
    containerd \
    runc \
    cni \
    kube \
    crictl-containerd
  do
    run_on_node "$NODE" "$SCRIPT_DIR/lib/kube-bootstrap/injections/$script.sh"
    sleep 2
  done
}

init_control_plane() {
  # Function that initialize control-plane nodes
  NODE_NAME="${CP_PREFIX}-1"
  CP_IP=$(multipass exec "$NODE_NAME" -- hostname -I | awk '{print $1}')

  log "Initializing control-plane on $NODE_NAME ($CP_IP)"

  run_on_node "$NODE_NAME" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/kubeadm-init.sh"
  
  sleep 2

  # VM User 
  multipass exec control-plane-1 -- bash -c '
    mkdir -p $HOME/.kube
    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    chmod 600 $HOME/.kube/config
  '
}

join_workers() {
  # Function that joins wrokers to the cluster
  CP_NODE="$CP_PREFIX-1"

  JOIN_CMD=$(multipass exec "$CP_NODE" -- sudo kubeadm token create --print-join-command)
  
  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    log "Joining worker $NODE"
    multipass exec "$NODE" -- sudo bash -c "$JOIN_CMD"
    sleep 2
  done
}

install_calico_operator() {
  # function installing the calico operator
  local CP_NODE="${CP_PREFIX}-1"

  log "Installing Calico (Tigera Operator) on $CP_NODE"
  # On passe explicitement les paires CLE=VALEUR

  run_on_node "$NODE" "$SCRIPT_DIR/lib/kube-bootstrap/injections/cni.sh" "VERSION=$CNI_VERSION URL=$CNI_URL"
  # run_on_node "$CP_NODE" "$SCRIPT_DIR/lib/kube-bootstrap/injections/calico.sh"
}