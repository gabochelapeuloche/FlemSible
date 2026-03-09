#!/usr/bin/env bash
set -Eeuo pipefail

# Récupération sécurisée
NODE_PORTS_RAW="${NODE_PORTS_ARRAY:-[]}"
CNI_PORTS_RAW="${CNI_PORTS_ARRAY:-[]}"

apply() {
  sudo apt-get update >/dev/null
  sudo apt-get install -y ufw jq >/dev/null

  # Configuration de la politique de Forwarding (CRUCIAL pour Calico/CNI)
  # Par défaut, UFW bloque le transit de paquets entre interfaces.
  # sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

  # Reset et politiques par défaut
  sudo ufw --force reset >/dev/null
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # Autorisations Vitales
  # Autoriser tout sur loopback (indispensable pour les services locaux)
  # sudo ufw allow in on lo >/dev/null
  # sudo ufw allow out on lo >/dev/null

  # Autoriser le trafic venant des autres nœuds Multipass (Subnet par défaut)
  # Multipass utilise généralement 10.0.0.0/8 ou 192.168.64.0/24 selon l'OS.
  # sudo ufw allow from 10.0.0.0/8 >/dev/null
  # sudo ufw allow from 192.168.0.0/16 >/dev/null

  # Autoriser le DNS (pour le pull d'images)
  sudo ufw allow 53/udp >/dev/null
  sudo ufw allow 53/tcp >/dev/null

  # Application des ports spécifiques (K8s + CNI)
  local NODE_PORTS_LIST=$(echo "$NODE_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")
  local CNI_PORTS_LIST=$(echo "$CNI_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")

  for port in $NODE_PORTS_LIST $CNI_PORTS_LIST; do
    if [[ -n "$port" ]]; then
      sudo ufw allow "$port" >/dev/null
    fi
  done

  # Activation
  sudo ufw --force enable >/dev/null
  echo "[firewall] configured: internal traffic allowed + forward policy ACCEPT"
}

main() {
  apply
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"