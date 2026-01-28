#!/usr/bin/bash

### Is multipass installed ?
if ! command -v multipass &> /dev/null; then
    echo "Erreur : multipass n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

### Default values
W_NUMBER=2
W_PREFIX=worker
CP_NUMBER=1
CP_PREFIX=control-plane
OS_VERSION="noble"
CPUS=2
MEMORY=3G
DISK=15G
VERBOSE=false
SNAPSHOT=false
CONNEXION_TEST=true
NET_OPT=()
if [[ -n "${NETWORK:-}" ]]; then
  NET_OPT=(--network "$NETWORK")
fi

### Functions
is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_storage() {
  [[ "$1" =~ ^[0-9]{1,4}G ]]
}

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --cp-number N
  --w-number N
  --cpus N
  --memory SIZE
  --disk SIZE
  --verbose
EOF
}

prepare_node() {
  multipass exec "$1" -- bash -c "
    set -e

    # Désactiver swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab

    # Modules kernel
    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    # Sysctl Kubernetes
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sudo sysctl --system

    # Containerd
    sudo apt update
    sudo apt install -y containerd

    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    sudo systemctl restart containerd
    sudo systemctl enable containerd

    # Kubernetes packages
    sudo apt install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt update
    sudo apt install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
  "
}

### Users customizations
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --cp-number)
      CP_NUMBER="$2"
      if ! is_number "$CP_NUMBER"; then
        echo "CP_NUMBER doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --w-number)
      W_NUMBER="$2"
      if ! is_number "$W_NUMBER"; then
        echo "W_NUMBER doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      if ! is_number "$CPUS"; then
        echo "CPUS doit être un entier"
        exit 1
      fi
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      if ! is_storage "$MEMORY"; then
        echo "MEMORY doit être de la forme XG avec X un entier positif"
        exit 1
      fi
      shift 2
      ;;
    --disk)
      DISK="$2"
      if ! is_number "$DISK"; then
        echo "DISK doit être de la forme XG avec X un entier positif"
        exit 1
      fi
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
  VMS+=("$CP_PREFIX-$i")
done

for ((i=1; i<=$W_NUMBER; i++)); do
  VMS+=("$W_PREFIX-$i")
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
  --disk "$DISK" \
  "${NET_OPT[@]}"
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

# Security groups
for NODE in "${VMS[@]}"; do
    multipass exec $NODE -- bash -c "
      sudo apt update && sudo apt install -y ufw
      sudo ufw --force reset
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow 22/tcp
      
      # calico 
      sudo ufw allow 179/tcp
      sudo ufw allow 5473/tcp
      "

  if [[ "$NODE" =~ ^"$CP_PREFIX" ]]; then
    # Regles spé du control plane
    multipass exec $NODE -- bash -c "
      
      # Kubernetes API server (6443) (accessible à tout le range ip du cluster)
      sudo ufw allow 6443/tcp
      
      # etcd (2379-2380)
      sudo ufw allow 2379:2380/tcp
      
      # kubelet API sched kcm
      sudo ufw allow 10249:10260/tcp
      
      sudo ufw enable
    "
  else
    # Règles spé des workers
    multipass exec $NODE -- bash -c "

      # Autoriser kubelet API (normalement limité à controlplane)
      sudo ufw allow 10250/tcp
      
      # Autoriser kube-proxy (normalement limité à controlplane)
      sudo ufw allow 10256/tcp
      
      # NodePort range (exposé publiquement)
      sudo ufw allow 30000:32767/tcp
      sudo ufw allow 30000:32767/udp
      
      sudo ufw enable
    "
  fi
done

for NODE in "${VMS[@]}"; do
  prepare_node "$NODE"
done
