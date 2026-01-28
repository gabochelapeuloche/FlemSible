#!/usr/bin/env bash

: '
  This bash file contains utilities used for running the programm smoothly
  and log the process.
'

# A function that setup the common firewall rules applied to all nodes
setup_ufw_common() {
  multipass exec "$1" -- bash -c "
    sudo apt update && sudo apt install -y ufw
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw enable
  "
}

# A function that setup the control-plane specific firewall rules
setup_ufw_cp() {
  multipass exec "$1" -- bash -c "
    sudo ufw allow 6443/tcp
    sudo ufw allow 2379:2380/tcp
    sudo ufw allow 10249:10260/tcp
    sudo ufw enable
  "
}

# A function that setup the worker specific firewall rules
setup_ufw_worker() {
  multipass exec "$1" -- bash -c "
    sudo ufw allow 10250/tcp
    sudo ufw allow 10256/tcp
    sudo ufw allow 30000:32767/tcp
    sudo ufw allow 30000:32767/udp
    sudo ufw enable
  "
}

# A function that setup the calico specific firewall rules
setup_ufw_calico() {
    multipass exec "$1" -- bash -c "
    sudo ufw allow 179/tcp
    sudo ufw allow 5473/tcp
    sudo ufw enable
  "
}