#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/containerd.sh — containerd installation.
#
# Downloads and installs containerd from the official GitHub release, installs
# the systemd service unit, and configures the SystemdCgroup driver required
# by kubeadm. Baked into the base image — skipped at provision time when
# BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: VERSION, CHECK_SUM_URL (tarball URL), SERVICE_URL (service file URL)
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
CHECK_SUM_URL="${CHECK_SUM_URL:-}"
SERVICE_URL="${SERVICE_URL:-}"

COMPONENT="containerd"

# is_installed
# Return 0 if containerd is already present in PATH, 1 otherwise.
is_installed() {
  command -v containerd >/dev/null 2>&1
}

# install
# Download the containerd tarball, extract to /usr/local, install the systemd
# service unit, generate the default config, and enable SystemdCgroup.
install() {
  curl -fsSLO "$CHECK_SUM_URL"
  sudo tar -C /usr/local -xzf "containerd-${VERSION}-linux-amd64.tar.gz"

  curl -fsSLO "$SERVICE_URL"
  sudo mkdir -p /usr/local/lib/systemd/system
  sudo mv containerd.service /usr/local/lib/systemd/system/

  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  # kubeadm requires the systemd cgroup driver
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

  sudo systemctl daemon-reexec
  sudo systemctl enable --now containerd
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main
