#!/usr/bin/env bash
set -Eeuo pipefail

echo "[network] configuring kernel modules and sysctl for Kubernetes"

# Modules à charger
modules=(overlay br_netfilter)

# Créer le fichier modules-load si nécessaire
K8S_MODULES_CONF="/etc/modules-load.d/k8s.conf"
for mod in "${modules[@]}"; do
  if ! grep -qx "$mod" "$K8S_MODULES_CONF" 2>/dev/null; then
    echo "$mod" | sudo tee -a "$K8S_MODULES_CONF" >/dev/null
  fi
  sudo modprobe "$mod"
done

# Sysctl parameters required by Kubernetes
K8S_SYSCTL_CONF="/etc/sysctl.d/k8s.conf"
declare -A sysctls=(
  [net.bridge.bridge-nf-call-iptables]=1
  [net.bridge.bridge-nf-call-ip6tables]=1
  [net.ipv4.ip_forward]=1
)

# Write sysctl config idempotently
for key in "${!sysctls[@]}"; do
  if ! grep -Eq "^\s*$key\s*=" "$K8S_SYSCTL_CONF" 2>/dev/null; then
    echo "$key = ${sysctls[$key]}" | sudo tee -a "$K8S_SYSCTL_CONF" >/dev/null
  fi
done

# Apply sysctl params immediately
sudo sysctl --system

# Verification
for mod in "${modules[@]}"; do
  lsmod | grep -q "^$mod" || { echo "❌ Kernel module $mod not loaded"; exit 1; }
done

for key in "${!sysctls[@]}"; do
  value=$(sysctl -n "$key")
  [[ "$value" == "${sysctls[$key]}" ]] || { echo "❌ $key=$value (expected ${sysctls[$key]})"; exit 1; }
done

echo "[network] kernel modules and sysctl parameters configured successfully"