main.sh:
#!/usr/bin/env bash
set -Eeuo pipefail

: '
  Main file of the script orchestrating the setup of a virtual kubernetes cluster on
  ubuntu machines using multipass
'

####
## Requirements en script variables
####

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/multipass.sh"
source "$SCRIPT_DIR/lib/kubeadm.sh"

require_cmd multipass

####
## Multipass VMS setup
####

log "\nusers customization\n"

section "user custom"

user_inputs "$@"

validate_config

section "Cluster configuration"
log "Control-plane number : $CP_NUMBER"
log "Workers number       : $W_NUMBER"
log "CP prefix            : $CP_PREFIX"
log "Worker prefix        : $W_PREFIX"
log "OS version           : $OS_VERSION"
log "CPUs                 : $CPUS"
log "Memory               : $MEMORY"
log "Disk                 : $DISK"

section "creation des vms"

create_vms

section "Preparing nodes"
for NODE in "${VMS[@]}"; do
  prepare_node "$NODE" &
done
wait

####
## Kubernetes Bootstrap
####

section "Kubernetes bootstrap"
init_control_plane
join_workers
install_calico_operator

kubectl get nodes -o wide
section "Cluster ready 🎉"



config.sh:
#!/usr/bin/env bash

####
## Cluster
####

CP_NUMBER=1
W_NUMBER=2
CP_PREFIX=control-plane
W_PREFIX=worker

####
## VM
####

OS_VERSION="noble"
CPUS=2
MEMORY=2G
DISK=15G
NETWORK=""

####
## Kubernetes
####

K8S_VERSION="v1.29"
POD_CIDR="192.168.0.0/16"
CNI="calico"

####
## Options
####

VERBOSE=false
SNAPSHOT=false
CONNEXION_TEST=true
SET_UP_TEST=true
DRY_RUN=false



./lib/utils.sh
#!/usr/bin/env bash

: '
Utilities for logging, error handling and CLI parsing
'



####
## Logging (verbose only)
####
log() {
  [[ "${VERBOSE:-false}" == true ]] || return 0
  printf "%b\n" "$*"
}

####
## Visual section for user
####
section() {
  log ""
  log "=== $* ==="
}



####
## Error handling
####
die() {
  printf "❌ %b\n" "$*" >&2
  exit 1
}

####
## Requirements
####
require_cmd() {
  command -v "$1" &>/dev/null || die "$1 n'est pas installé"
}

# Helpers
is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_storage() {
  [[ "$1" =~ ^[0-9]+[MG]$ ]]
}

# Usage
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --cp-number N
  --w-number N
  --cpus N
  --memory XG
  --disk XG
  --network NAME
  --verbose
  -h, --help
EOF
}

# CLI parsing
user_inputs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --cp-number)
        CP_NUMBER="$2"
        is_number "$CP_NUMBER" || die "CP_NUMBER doit être un entier"
        shift 2
        ;;
      --w-number)
        W_NUMBER="$2"
        is_number "$W_NUMBER" || die "W_NUMBER doit être un entier"
        shift 2
        ;;
      --cpus)
        CPUS="$2"
        is_number "$CPUS" || die "CPUS doit être un entier"
        shift 2
        ;;
      --memory)
        MEMORY="$2"
        is_storage "$MEMORY" || die "MEMORY doit être de la forme XG"
        shift 2
        ;;
      --disk)
        DISK="$2"
        is_storage "$DISK" || die "DISK doit être de la forme XG"
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
        die "Option inconnue : $1"
        ;;
    esac
  done
}

# Global validation
validate_config() {
  [[ "$CP_NUMBER" -ge 1 ]] || die "CP_NUMBER must be >= 1"
  [[ "$W_NUMBER" -ge 0 ]] || die "W_NUMBER must be >= 0"
}

remote_exec() {
  local NODE="$1"
  local SCRIPT="$2"

  multipass exec "$NODE" -- bash -c "
    set -Eeuo pipefail
    $SCRIPT
  "
}




./lib/ufw.sh

#!/usr/bin/env bash

: '
Firewall configuration for Kubernetes nodes (UFW)
'

configure_firewall() {
  local VM="$1"
  local ROLE="$2"   # cp | worker
  local CNI="$3"

  multipass exec "$VM" -- bash -c "
    set -e

    sudo apt update
    sudo apt install -y ufw

    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp

    if [[ \"$ROLE\" == \"cp\" ]]; then
      sudo ufw allow 6443/tcp
      sudo ufw allow 2379:2380/tcp
      sudo ufw allow 10249:10260/tcp
    fi

    if [[ \"$ROLE\" == \"worker\" ]]; then
      sudo ufw allow 10250/tcp
      sudo ufw allow 10256/tcp
      sudo ufw allow 30000:32767/tcp
      sudo ufw allow 30000:32767/udp
    fi

    if [[ \"$CNI\" == \"calico\" ]]; then
      sudo ufw allow 179/tcp
      sudo ufw allow 5473/tcp
    fi

    sudo ufw enable
  "
}

test_firewall() {
  local VM="$1"
  local ROLE="$2"
  local CNI="$3"
}




./lib/multipass.sh
#!/usr/bin/env bash

: '
Virtual infrastructure management using Multipass
'

configure_vm() {
  local VM="$1"

  case "$VM" in
    "$CP_PREFIX"-*)
      configure_firewall "$VM" "cp" "$CNI"
      ;;
    "$W_PREFIX"-*)
      configure_firewall "$VM" "worker" "$CNI"
      ;;
  esac
}

create_vms() {
  VMS=()

  for ((i=1; i<=CP_NUMBER; i++)); do
    VMS+=("$CP_PREFIX-$i")
  done

  for ((i=1; i<=W_NUMBER; i++)); do
    VMS+=("$W_PREFIX-$i")
  done

  log "Creating VMs:"
  for vm in "${VMS[@]}"; do
    log "  - $vm"
  done

  for VM in "${VMS[@]}"; do
    multipass info "$VM" &>/dev/null && die "La VM $VM existe déjà"
  done

  # Create all VMs first
  for VM in "${VMS[@]}"; do
    multipass launch "$OS_VERSION" \
      --name "$VM" \
      --cpus "$CPUS" \
      --memory "$MEMORY" \
      --disk "$DISK"
  done

  # Configure firewall in parallel
  for VM in "${VMS[@]}"; do
    configure_vm "$VM" &
  done
  wait
}





./lib/kubeadm.sh
#!/usr/bin/env bash

: '
  This file contains script for preparing the virtual machines to receive a node (master
  or control-plane)
'

verify_node_networking() {
  local NODE="$1"

  multipass exec "$NODE" -- bash -c '
    set -e

    for mod in br_netfilter overlay; do
      lsmod | grep -q "^$mod" || exit 10
    done

    sysctl -n net.bridge.bridge-nf-call-iptables | grep -qx 1
    sysctl -n net.bridge.bridge-nf-call-ip6tables | grep -qx 1
    sysctl -n net.ipv4.ip_forward | grep -qx 1
  ' || die "$NODE: networking prerequisites not met"
}

# Function that runs on every node to do the common setup
prepare_node() {
  local NODE="$1"

  log "Preparing node $NODE"

  for script in \
    disable-swap \
    ipv4-forward-iptables \
    cri \
    runc \
    cni \
    kube \
    crictl2containerd
  do
    log "  → $script"
    remote_exec "$NODE" "$( < "$SCRIPT_DIR/lib/kubeadm-files/$script.sh" )"
  done

  log "Verifying networking prerequisites"
  verify_node_networking "$NODE"

  multipass exec "$NODE" -- systemctl is-active --quiet containerd \
    || die "containerd is not running on $NODE"
}

# Function that initialize control-plane nodes
init_control_plane() {
  CP_NODE="${CP_PREFIX}-1"

  CP_IP=$(multipass exec "$CP_NODE" -- hostname -I | awk '{print $1}')

  multipass exec "$CP_NODE" -- sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR"

  mkdir -p ~/.kube
  multipass exec "$CP_NODE" -- sudo mkdir -p /root/.kube
  multipass exec "$CP_NODE" -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config
  multipass exec "$CP_NODE" -- sudo cp /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 ~/.kube/config
}

join_workers() {
  CP_NODE="${CP_PREFIX}-1"

  JOIN_CMD=$(multipass exec "$CP_NODE" -- sudo kubeadm token create --print-join-command)
  
  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    log "Joining worker $NODE"
    multipass exec "$NODE" -- sudo bash -c "$JOIN_CMD"
  done
}

install_calico_operator() {
  local CP_NODE="${CP_PREFIX}-1"

  log "Installing Calico (Tigera Operator) on $CP_NODE"

  multipass exec "$CP_NODE" -- sudo bash -c "
    $(< "$SCRIPT_DIR/lib/kubeadm-files/calico.sh")
  "
}






./lib/kubeadm-files/calico.sh
#!/usr/bin/env bash
set -Eeuo pipefail

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml || true
kubectl rollout status deployment/tigera-operator -n tigera-operator --timeout=120s
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml



./lib/kubeadm-files/cni.sh
# This file containes the script for installing the cni pluggin on control plane and worker nodes
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.0.tgz




./lib/kubeadm-files/cri.sh
# script for installing cri on control plane and worker nodes
curl -LO https://github.com/containerd/containerd/releases/download/v1.7.14/containerd-1.7.14-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-1.7.14-linux-amd64.tar.gz
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mkdir -p /usr/local/lib/systemd/system/
sudo mv containerd.service /usr/local/lib/systemd/system/
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl daemon-reload
sudo systemctl enable --now containerd




./lib/kubeadm-files/crictl2containerd.sh
# This file contains srcipt for enabling crictl to manage docker d
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock





./lib/kubeadm-files/disable-swap.sh
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





./lib/kubeadm-files/init-cp.sh
sudo kubeadm init \
  --apiserver-advertise-address="$CP_IP" \
  --pod-network-cidr="$POD_CIDR" \
  --node-name master





./lib/kubeadm-files/ipv4-forward-iptables.sh
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







./lib/kubeadm-files/kube.sh
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet=1.29.6-1.1 kubeadm=1.29.6-1.1 kubectl=1.29.6-1.1 --allow-downgrades --allow-change-held-packages
sudo apt-mark hold kubelet kubeadm kubectl

kubeadm version
kubelet --version
kubectl version --client






./lib/kubeadm-files/kubeconfig.sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config





./lib/kubeadm-files/runc.sh
curl -LO https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc