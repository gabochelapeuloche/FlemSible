#!/usr/bin/bash

### Is multipass installed ?
if ! command -v multipass &> /dev/null; then
    echo "Erreur : multipass n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

### Default values
W_NUMBER=2
CP_NUMBER=1
OS_VERSION="noble"
CPUS=2
MEMORY=3G
DISK=15G
VERBOSE=false
SNAPSHOT=false
CONNEXION_TEST=true

### Users customizations
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cp-number)
      CP_NUMBER="$2"
      shift 2
      ;;
    --w-number)
      W_NUMBER="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --disk)
      DISK="$2"
      shift 2
      ;;
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Option inconnue : $1"
      exit 1
    ;;
  esac
done

### VMs lists
VMS=()

for ((i=1; i<=$CP_NUMBER; i++)); do
  VMS+=("control-plane-$i")
done

for ((i=1; i<=$W_NUMBER; i++)); do
  VMS+=("worker-$i")
done

if [[ "$VERBOSE" = true ]]; then
  echo "creation des vms :"
  printf '  - %s\n' "${VMS[@]}"
fi

# verification de la pre-existance de vm au meme noms
for VM in "${VMS[@]}"; do
  if multipass info "$VM" >/dev/null 2>&1; then
    printf "\nLe nom $VM est déjà utilisé."
    read -p "Souhaitez-vous la supprimer ? (Y/N): " confirm
    if [[ "$confirm" =~ ^[Yy](es)?$ ]]; then
      if ! multipass stop "$VM" >/dev/null 2>&1; then
        echo "Erreur lors de l'arrêt de $VM (peut-être déjà arrêtée)."
      fi
      if ! multipass delete "$VM" >/dev/null 2>&1; then
        echo "Erreur lors de la suppression de $VM."
      fi
      multipass purge >/dev/null 2>&1
    else
      echo "Annulation de la création des VMs."
      exit 1
    fi
  fi
done

# Lancer les VMs
for NODE in "${VMS[@]}"; do
  multipass launch "$OS_VERSION" \
  --name "$NODE" \
  --cpus "$CPUS" \
  --memory "$MEMORY" \
  --disk "$DISK"
done

# Tester la communication entre VMs
if [[ "$VERBOSE" = true ]]; then
  printf "\nTest de la communication inter VMs :"
fi

for NODE1 in "${VMS[@]}"; do
  for NODE2 in "${VMS[@]}"; do
    if [[ "$NODE1" != "$NODE2" ]]; then
      
      IP_NODE2=$(multipass exec "$NODE2" -- hostname -I | awk '{print $1}')
      
      PING_RESULT=$(multipass exec "$NODE1" -- ping -c 3 "$IP_NODE2" 2>&1)
      
      if [[ "$VERBOSE" = true ]]; then
        if echo "$PING_RESULT" | grep -q "0% packet loss"; then
          printf '  - %s\n' "$NODE1 --> $NODE2 : connexion reussie"
        else
          printf '  - %s\n' "$NODE1 --> $NODE2 : connexion echouee"
        fi
      fi
    fi
  done
done

# Créer une snapshot des VMs
if [[ "$SNAPSHOT" = true ]]; then
  
  if [[ "$VERBOSE" = true ]]; then
    printf "\nCreation des snapshots :"
  fi

  for NODE in "${VMS[@]}"; do
    printf '  - %s\n' "$NODE"
    multipass stop "$NODE"
    multipass snapshot "$NODE" --name "${NODE}-bare" --comment "instance before kube installation"
    multipass start "$NODE"
  done
fi
