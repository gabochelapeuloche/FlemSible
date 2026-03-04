# Setting up containerd on both conrtol-plane and worker nodes
# This script will need to be executed directly on the host

#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="containerd"

# Arguments to feed before injecting script into the nodes
VERSION="JSONVALUE"
CHECK_SUM_URL="JSONVALUE"
SERVICE_URL="JSONVALUE"

is_installed() {
  command -v containerd >/dev/null 2>&1
}

install() {
  # donwload containerd archive and verify sha256sum
  curl -fsSLO "$CHECK_SUM_URL"
  sudo tar -C /usr/local -xzf "containerd-${VERSION}-linux-amd64.tar.gz"
  
  # Install systemd to start containerd
  curl -fsSLO "$SERVICE_URL"
  sudo mkdir -p /usr/local/lib/systemd/system
  sudo mv containerd.service /usr/local/lib/systemd/system/

  # Configurer le systemd cgroupdriver
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

  # Reload le service
  sudo systemctl daemon-reexec
  sudo systemctl enable --now containerd
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main