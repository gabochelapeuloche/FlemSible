#!/usr/bin/env bash
set -Eeuo pipefail

echo "[swap] disabling swap if enabled"

# Désactiver le swap si actif
if swapon --summary | grep -q .; then
  sudo swapoff -a
fi

# Commenter uniquement les lignes swap NON commentées
if grep -Eq '^[^#].*\sswap\s' /etc/fstab; then
  sudo sed -i.bak '/^[^#].*\sswap\s/s/^/#/' /etc/fstab
fi

# Vérification
if swapon --summary | grep -q .; then
  echo "❌ swap is still enabled"
  exit 1
fi

echo "[swap] swap successfully disabled"