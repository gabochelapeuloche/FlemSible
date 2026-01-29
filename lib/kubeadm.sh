#!/usr/bin/env bash

: '
  This file contains script for preparing the virtual machines to receive a node (master
  or control-plane)
'

# Function that runs on every node to do the common setup
prepare_node() {
  local NODE="$1"

  # Setup


  #1# Disable swapp
  FILE_CONTENT=$(< kubeadm-files/disable-swap.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"
  # Verification


  #2# Forwarding IPv4 and letting iptables see bridged traffic
  FILE_CONTENT=$(< kubeadm-files/ipv4-forward-iptables.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"
  # Verification
  multipass exec "$NODE" -- lsmod | grep br_netfilter
  multipass exec "$NODE" -- lsmod | grep overlay
  multipass exec "$NODE" -- sysctl \
    net.bridge.bridge-nf-call-iptables \
    net.bridge.bridge-nf-call-ip6tables \
    net.ipv4.ip_forward


  #3# Install container runtime
  FILE_CONTENT=$(< kubeadm-files/cri.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"
  # Verification
  systemctl status containerd # Check that containerd service is up and running


  #4# Install runc
  FILE_CONTENT=$(< kubeadm-files/runc.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"
  # Verification


  #5# install cni plugin
  FILE_CONTENT=$(< kubeadm-files/cni.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"


  #6# Install kubeadm, kubelet and kubectl
  FILE_CONTENT=$(< kubeadm-files/kube.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"


  #7# Configure crictl to work with containerd
  FILE_CONTENT=$(< kubeadm-files/crictl2containerd.sh)
  multipass exec "$NODE" -- bash -c "$FILE_CONTENT"
}

# Function that initialize control-plane nodes
init_control_plane() {
  CP_NODE="${CP_PREFIX}-1"
  CP_IP=$(multipass exec "$CP_NODE" -- hostname -I | awk '{print $1}')

  multipass exec "$CP_NODE" -- sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR"
}

# Function that initializa worker nodes
join_workers() {
  JOIN_CMD=$(multipass exec "$CP_NODE" -- kubeadm token create --print-join-command)

  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    multipass exec "$NODE" -- sudo $JOIN_CMD
  done
}