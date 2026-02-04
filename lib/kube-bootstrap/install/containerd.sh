#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="containerd"
VERSION="1.7.14"

is_installed() {
  command -v containerd >/dev/null 2>&1
}

install() {
  curl -fsSLO "https://github.com/containerd/containerd/releases/download/v${VERSION}/containerd-${VERSION}-linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf "containerd-${VERSION}-linux-amd64.tar.gz"

  curl -fsSLO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
  sudo mkdir -p /usr/local/lib/systemd/system
  sudo mv containerd.service /usr/local/lib/systemd/system/

  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

  sudo systemctl daemon-reexec
  sudo systemctl enable --now containerd
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main