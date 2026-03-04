#!/usr/bin/env bash

# This file contains functions to call from host and run scripts on passed as argument nodes 
# Those functions prepare the virtual machines to receive a node (master or control-plane)

prepare_node() {
  # Function that runs on every node to do the common setup
  local NODE="$1"
  
  print_cue "Preparing node $NODE"
  print_cue "Installing kubernetes components"
  
  # Executing containerd script on node
  run_on_node_env "$NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/containerd.sh" \
    "VERSION=$CONTAINERD_VERSION CHECK_SUM_URL=$CONTAINERD_URL SERVICE_URL=$CONTAINERD_SERVICE_URL"
  sleep 2

  # Executing runc script on node
  run_on_node_env "$NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/runc.sh" \
    "VERSION=$RUNC_VERSION URL=$RUNC_URL"
  sleep 2

  # Executing cni script on node
  run_on_node_env "$NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/cni.sh" \
    "VERSION=$CNI_VERSION URL=$CNI_URL"
  sleep 2

  # Executing kube script on node
  run_on_node_env "$NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/kube.sh" \
    "VERSION=$K8S_PATCH URL=$K8S_REPO RELEASE_KEY=$K8S_RELEASE_KEY"
  sleep 2

  # Executing crictl-containerd script on node
  run_on_node_env "$NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/crictl-containerd.sh" \
    ""
  sleep 2
}

init_control_plane() {
  # Function that initialize control-plane nodes
  NODE_NAME="${CP_PREFIX}-1"
  CP_IP=$(multipass exec "$NODE_NAME" -- hostname -I | awk '{print $1}')

  print_cue "Initializing control-plane on $NODE_NAME ($CP_IP)"

  run_on_node_env "$NODE_NAME" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/kubeadm-init.sh" \
    "POD_CIDR=$CP_POD_CIDR"
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
    print_cue "Joining worker $NODE"
    multipass exec "$NODE" -- sudo bash -c "$JOIN_CMD"
    sleep 2
  done
}

install_calico_operator() {
  # function installing the calico operator
  local CP_NODE="${CP_PREFIX}-1"

  print_cue "Installing Calico (Tigera Operator) on $CP_NODE"

  # Execution
  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/calico.sh" \
    "VERSION=$CALICO_VERSION OPERATOR_URL=$CALICO_TIGERA_OPERATOR CUSTOM_RESOURCES_URL=$CALICO_CRD_URL"
}