#!/usr/bin/env bash

: '
Utilities for logging, error handling and CLI parsing
'

log() {
  # logging for verbose option
  [[ "${VERBOSE:-false}" == true ]] || return 0
  printf "%b\n" "$*"
}

section() {
  # Visual section for user when verbose option is used
  log ""
  log "=== $* ==="
}

die() {
  # Error handling function
  printf "❌ %b\n" "$*" >&2
  exit 1
}

require_cmd() {
  # Requirements check function
  command -v "$1" &>/dev/null || die "$1 n'est pas installé"
}

is_number() {
  # Helper checking if an arg conforms to number
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_storage() {
  # Helper checking if an arg conforms to storage
  [[ "$1" =~ ^[0-9]+[MG]$ ]]
}

validate_config() {
  # Global validation
  [[ "$CP_NUMBER" -ge 1 ]] || die "CP_NUMBER must be >= 1"
  [[ "$W_NUMBER" -ge 0 ]] || die "W_NUMBER must be >= 0"
}

usage() {
  # Usage printing when help option is used
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

user_inputs() {
  # CLI options parsing
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --version)
        K8S_VERSION="$2"
        # is_number "$CP_NUMBER" || die "CP_NUMBER doit être un entier"
        shift 2
        ;;
      --cp-number)
        CP_NUMBER_USER="$2"
        is_number "$CP_NUMBER" || die "CP_NUMBER doit être un entier"
        shift 2
        ;;
      --w-number)
        W_NUMBER_USER="$2"
        is_number "$W_NUMBER" || die "W_NUMBER doit être un entier"
        shift 2
        ;;
      --cpus)
        CPUS_USER="$2"
        is_number "$CPUS" || die "CPUS doit être un entier"
        shift 2
        ;;
      --memory)
        MEMORY_USER="$2"
        is_storage "$MEMORY" || die "MEMORY doit être de la forme XG"
        shift 2
        ;;
      --disk)
        DISK_USER="$2"
        is_storage "$DISK" || die "DISK doit être de la forme XG"
        shift 2
        ;;
      --network)
        NETWORK_USER="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE_USER=true
        shift
        ;;
      *)
        die "Option inconnue : $1"
        ;;
    esac
  done
}

remote_exec() {
  # executiong a script directly on a vm through multipass exec
  local NODE="$1"
  local SCRIPT="$2"

  multipass exec "$NODE" -- bash -c "
    set -Eeuo pipefail
    $SCRIPT
  "
}

run_on_node() {
  local NODE="$1"
  local SRC="$2"
  local MAPPINGS="${3:-}"
  
  local NAME=$(basename "$SRC")
  # Création d'un sous-dossier de travail pour plus de propreté
  local WORK_DIR="$SCRIPT_DIR/tmp/k8s-deploy-$(id -u)"
  mkdir -p "$WORK_DIR"
  
  local TMP="$WORK_DIR/${NODE}_${NAME}"
  
  # 1. Préparation
  cp "$SRC" "$TMP"

  # 2. Injection
  if [[ -n "$MAPPINGS" ]]; then
    for map in $MAPPINGS; do
      local key="${map%%=*}"
      local value="${map##*=}"
      sed -i "s|$key=\"JSONVALUE\"|$key=\"$value\"|g" "$TMP"
    done
  fi

  # 3. Transfert avec vérification
  if [[ -f "$TMP" ]]; then
    # On laisse un micro-délai pour éviter les collisions I/O
    sleep 0.2
    multipass exec "$NODE" -- mkdir -p "/tmp/"
    multipass transfer "$TMP" "$NODE:/tmp/$NAME"
    multipass exec "$NODE" -- sudo chmod +x "/tmp/$NAME"
    multipass exec "$NODE" -- sudo bash "/tmp/$NAME"
    
    # 4. Nettoyage DIFFÉRÉ
    # On ne supprime le fichier local QUE quand on est sûr 
    # que l'exécution distante est lancée ou terminée.
    # rm -f "$TMP"
    # multipass exec "$NODE" -- rm -f "/tmp/$NAME"
  else
    echo "❌ Erreur : Fichier source $TMP manquant"
    return 1
  fi
}

clean_node() {
  # cleaning remaning setups scripts
  local NODE="$1"
  multipass exec "$NODE" -- sudo rm -f "/tmp/$NAME"
}

load_versions() {
  # loading global variables to feed to the script
  get_version_info "$K8S_VERSION"
}

get_version_info() {
    local VERSION=$1
    local JSON_FILE="$SCRIPT_DIR/versions.json"

    if [[ ! -f "$JSON_FILE" ]]; then
        die "Fichier versions.json introuvable."
    fi

    # Informations about virtual layer
    # Control-plane
    local JSON_PATH=".\"$VERSION\".\"virtual-layer\".\"control-plane\""
    CP_PREFIX=$(jq -r "$JSON_PATH.name" "$JSON_FILE")
    CP_NUMBER=$(jq -r "$JSON_PATH.count" "$JSON_FILE")
    CP_OPEN_PORTS=$(jq -r "$JSON_PATH.ports // []" "$JSON_FILE")
    CP_OS_VERSION=$(jq -r "$JSON_PATH.\"os-version\"" "$JSON_FILE")
    CP_CPUS=$(jq -r "$JSON_PATH.cpus" "$JSON_FILE")
    CP_MEMORY=$(jq -r "$JSON_PATH.memory" "$JSON_FILE")
    CP_DISK=$(jq -r "$JSON_PATH.disk" "$JSON_FILE")
    CP_POD_CIDR=$(jq -r "$JSON_PATH.cidr" "$JSON_FILE")

    # Worker
    local JSON_PATH=".\"$VERSION\".\"virtual-layer\".worker"
    W_PREFIX=$(jq -r "$JSON_PATH.name" "$JSON_FILE")
    W_NUMBER=$(jq -r "$JSON_PATH.count" "$JSON_FILE")
    W_OPEN_PORTS=$(jq -r "$JSON_PATH.ports // []" "$JSON_FILE")
    W_OS_VERSION=$(jq -r "$JSON_PATH.\"os-version\"" "$JSON_FILE")
    W_CPUS=$(jq -r "$JSON_PATH.cpus" "$JSON_FILE")
    W_MEMORY=$(jq -r "$JSON_PATH.memory" "$JSON_FILE")
    W_DISK=$(jq -r "$JSON_PATH.disk" "$JSON_FILE")

    # Extraction des infos Kubernetes
    local JSON_PATH=".\"$VERSION\".kubernetes"
    K8S_MINOR=$(jq -r "$JSON_PATH.minor" "$JSON_FILE")
    K8S_PATCH=$(jq -r "$JSON_PATH.patch" "$JSON_FILE")
    K8S_PKG_VERSION=$(jq -r "$JSON_PATH.pkg_version" "$JSON_FILE")
    K8S_REPO=$(jq -r "$JSON_PATH.repo_url" "$JSON_FILE")

    # Extraction des composants
    # container-runtime
    local JSON_PATH=".\"$VERSION\".components.\"container-runtime\".containerd"
    CONTAINERD_VERSION=$(jq -r "$JSON_PATH.version" "$JSON_FILE")
    CONTAINERD_URL=$(jq -r "$JSON_PATH.url" "$JSON_FILE")
    
    # runc
    local JSON_PATH=".\"$VERSION\".components.runc"
    RUNC_VERSION=$(jq -r "$JSON_PATH.version" "$JSON_FILE")
    RUNC_URL=$(jq -r "$JSON_PATH.url" "$JSON_FILE")

    # cni-plugin
    local JSON_PATH=".\"$VERSION\".components.\"cni-plugin\""
    CNI_VERSION=$(jq -r "$JSON_PATH.version" "$JSON_FILE")
    CNI_URL=$(jq -r "$JSON_PATH.url" "$JSON_FILE")
    
    # network-plugin
    local JSON_PATH=".\"$VERSION\".components.\"network-plugins\".calico"
    CNI="calico"
    CALICO_VERSION=$(jq -c "$JSON_PATH.version" "$JSON_FILE")
    CALICO_CRD_URL=$(jq -c "$JSON_PATH.\"tigera-operator\"" "$JSON_FILE")
    CALICO_TIGERA_OPERATOR=$(jq -c "$JSON_PATH.\"crd-url\"" "$JSON_FILE")
    CALICO_OPEN_PORTS=$(jq -c "$JSON_PATH.ports // []" "$JSON_FILE")
}