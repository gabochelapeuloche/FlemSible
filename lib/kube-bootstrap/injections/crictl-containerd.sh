#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/crictl-containerd.sh — crictl configuration.
#
# Configures crictl to use the containerd socket as its runtime endpoint.
# crictl is the CLI for interacting with the container runtime (debugging pods,
# pulling images, etc.) and is provided by the kubeadm package.
# Baked into the base image — skipped at provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes (requires crictl binary from kubeadm package)
# Injected: (none)
# =============================================================================
set -Eeuo pipefail

COMPONENT="crictl"
RUNTIME_ENDPOINT="unix:///var/run/containerd/containerd.sock"
CONFIG_FILE="/etc/crictl.yaml"

# is_configured
# Return 0 if /etc/crictl.yaml already points to the containerd socket.
is_configured() {
  [[ -f "$CONFIG_FILE" ]] &&
  grep -Eq "^runtime-endpoint:\s*$RUNTIME_ENDPOINT" "$CONFIG_FILE"
}

# install
# Write the runtime endpoint to the crictl config file.
install() {
  echo "[$COMPONENT] configuring runtime endpoint"
  sudo crictl config runtime-endpoint "$RUNTIME_ENDPOINT"
}

main() {
  is_configured || install
  echo "[$COMPONENT] configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
