# Applying network rules on different host based on their role
# This script will need to be executed directly on the host

#!/usr/bin/env bash

configure_firewall() {
  local VM="$1"
  local ROLE="$2" # cp | worker
  
  # 1. Extraction sur l'HÔTE (via jq sur le JSON chargé par le parser)
  local PORTS_LIST=""
  if [[ "$ROLE" == "cp" ]]; then
      PORTS_LIST=$(echo "$CP_OPEN_PORTS" | jq -r '. | join(" ")') # conversion du tableau en chaine
  else
      PORTS_LIST=$(echo "$W_OPEN_PORTS" | jq -r '. | join(" ")')
  fi

  # Ajout des ports CNI (Calico, etc.)
  local CNI_LIST=$(echo "$CALICO_OPEN_PORTS" | jq -r '. | join(" ")')

  # 2. Injection dans la commande distante
  multipass exec "$VM" -- bash -c "
    set -e
    sudo apt update && sudo apt install -y ufw
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Les ports sont injectés ici en dur par l'hôte dans la commande
    for port in $PORTS_LIST $CNI_LIST; do
      sudo ufw allow \"\$port\"
    done

    sudo ufw --force enable
    echo \"Firewall configured for $ROLE with ports: $PORTS_LIST $CNI_LIST\"
  "
}