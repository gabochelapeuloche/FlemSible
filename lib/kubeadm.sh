#!/usr/bin/env bash

: '
  This file contains script for preparing the virtual machines to receive a node (master
  or control-plane)
'

verify_node_networking() {
  local NODE="$1"

  multipass exec "$NODE" -- bash -c '
    set -e

    for mod in br_netfilter overlay; do
      lsmod | grep -q "^$mod" || exit 10
    done

    sysctl -n net.bridge.bridge-nf-call-iptables | grep -qx 1
    sysctl -n net.bridge.bridge-nf-call-ip6tables | grep -qx 1
    sysctl -n net.ipv4.ip_forward | grep -qx 1
  ' || die "$NODE: networking prerequisites not met"
}

# Function that runs on every node to do the common setup
prepare_node() {
  local NODE="$1"

  log "Preparing node $NODE"

  for script in \
    disable-swap \
    ipv4-forward-iptables \
    cri \
    runc \
    cni \
    kube \
    crictl2containerd
  do
    log "  → $script"
    remote_exec "$NODE" "$( < "$SCRIPT_DIR/lib/kubeadm-files/$script.sh" )"
  done

  log "Verifying networking prerequisites"
  verify_node_networking "$NODE"

  multipass exec "$NODE" -- systemctl is-active --quiet containerd \
    || die "containerd is not running on $NODE"
}

# Function that initialize control-plane nodes
init_control_plane() {
  CP_NODE="${CP_PREFIX}-1"

  CP_IP=$(multipass exec "$CP_NODE" -- hostname -I | awk '{print $1}')

  multipass exec "$CP_NODE" -- sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR"

  mkdir -p ~/.kube
  multipass exec "$CP_NODE" -- sudo mkdir -p /root/.kube
  multipass exec "$CP_NODE" -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 ~/.kube/config
}

join_workers() {
  CP_NODE="${CP_PREFIX}-1"

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

  multipass exec "$CP_NODE" -- sudo bash -c "
    $(< "$SCRIPT_DIR/lib/kubeadm-files/calico.sh")
  "
}