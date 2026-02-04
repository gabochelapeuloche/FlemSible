#!/usr/bin/env bash

: '
Firewall configuration for Kubernetes nodes (UFW)
'

configure_firewall() {
  local VM="$1"
  local ROLE="$2"   # cp | worker
  local CNI="$3"

  multipass exec "$VM" -- bash -c "
    set -e

    COMPONENT="ufw"

    sudo apt update
    sudo apt install -y ufw

    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp

    if [[ \"$ROLE\" == \"cp\" ]]; then
      sudo ufw allow 6443/tcp
      sudo ufw allow 2379:2380/tcp
      sudo ufw allow 10249:10260/tcp
    fi

    if [[ \"$ROLE\" == \"worker\" ]]; then
      sudo ufw allow 10250/tcp
      sudo ufw allow 10256/tcp
      sudo ufw allow 30000:32767/tcp
      sudo ufw allow 30000:32767/udp
    fi

    if [[ \"$CNI\" == \"calico\" ]]; then
      sudo ufw allow 179/tcp
      sudo ufw allow 5473/tcp
    fi

    sudo ufw --force enable

    sudo ufw status verbose | grep -q "Status: active" \
    || { echo "❌ UFW not active"; exit 1; }

    echo "[$COMPONENT] OK"
  "
}

test_firewall() {
  local VM="$1"
  local ROLE="$2"
  local CNI="$3"
}