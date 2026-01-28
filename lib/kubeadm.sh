#!/usr/bin/env bash

prepare_node() {
  local NODE="$1"

  multipass exec "$NODE" -- bash -c "
    set -e
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
    sudo modprobe overlay br_netfilter
    sudo sysctl --system
  "
}



### faut tout installer :)

init_control_plane() {
  CP_NODE="${CP_PREFIX}-1"
  CP_IP=$(multipass exec "$CP_NODE" -- hostname -I | awk '{print $1}')

  multipass exec "$CP_NODE" -- sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR"
}

join_workers() {
  JOIN_CMD=$(multipass exec "$CP_NODE" -- kubeadm token create --print-join-command)

  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    multipass exec "$NODE" -- sudo $JOIN_CMD
  done
}