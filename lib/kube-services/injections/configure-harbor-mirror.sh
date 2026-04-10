#!/usr/bin/env bash
# =============================================================================
# lib/kube-services/injections/configure-harbor-mirror.sh — Harbor mirror setup.
#
# Configures containerd to use Harbor as a pull-through mirror for docker.io.
# Falls back to Docker Hub automatically when:
#   - Harbor is unreachable
#   - The image is not in Harbor's cache (returns 404)
#
# Uses the containerd hosts.d approach: a per-registry hosts.toml file under
# /etc/containerd/certs.d/docker.io/ that lists mirror endpoints in priority
# order, with the upstream registry as the fallback via the `server` field.
#
# Runs on:  all nodes
# Injected: HARBOR_IP, HARBOR_PORT
# =============================================================================
set -Eeuo pipefail

HARBOR_IP="${HARBOR_IP:-}"
HARBOR_PORT="${HARBOR_PORT:-30002}"

COMPONENT="harbor-mirror"
CERTS_DIR="/etc/containerd/certs.d/docker.io"
CONFIG_TOML="/etc/containerd/config.toml"

[[ -n "$HARBOR_IP" ]] || { echo "❌ HARBOR_IP not injected"; exit 1; }

# Ensure containerd's registry config_path points to the certs.d directory.
# containerd 2.x defaults to config_path = "" — set it so hosts.toml is picked up.
sudo sed -i 's|config_path = ""|config_path = "/etc/containerd/certs.d"|g' "$CONFIG_TOML"

# Create the per-registry mirror config for docker.io.
# server = upstream fallback when Harbor is unreachable or image not cached.
sudo mkdir -p "$CERTS_DIR"
sudo tee "$CERTS_DIR/hosts.toml" > /dev/null <<EOF
server = "https://registry-1.docker.io"

[host."http://$HARBOR_IP:$HARBOR_PORT"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

sudo systemctl restart containerd

echo "[$COMPONENT] docker.io → Harbor (http://$HARBOR_IP:$HARBOR_PORT) with Docker Hub fallback"
