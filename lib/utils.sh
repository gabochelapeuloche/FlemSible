#!/usr/bin/env bash
# Utilities for logging, error handling and CLI parsing

print_cue() {
  # printing informations for verbose option (reserved for script state and UI not logging)
  # [[ "${VERBOSE:-false}" == true ]] || return 0
  printf "%b\n" "$*"
}

# Timing state — set when utils.sh is sourced (i.e. at script start)
_SCRIPT_START=$(date +%s)
_SECTION_START=0
_SECTION_NAME=""

section() {
  local now
  now=$(date +%s)

  # Print elapsed time for the section that just finished
  if [[ -n "$_SECTION_NAME" && "$_SECTION_START" -gt 0 ]]; then
    printf "    ↳ %ds\n" "$(( now - _SECTION_START ))"
  fi

  _SECTION_START=$now
  _SECTION_NAME="$*"
  print_cue ""
  print_cue "=== $* ==="
}

print_total_time() {
  local now elapsed
  now=$(date +%s)
  # Close the last open section
  if [[ -n "$_SECTION_NAME" && "$_SECTION_START" -gt 0 ]]; then
    printf "    ↳ %ds\n" "$(( now - _SECTION_START ))"
    _SECTION_START=0
  fi
  elapsed=$(( now - _SCRIPT_START ))
  printf "\nTotal: %dm%02ds\n" "$(( elapsed / 60 ))" "$(( elapsed % 60 ))"
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
        VERBOSE_USER="$2"
        shift
        ;;
      *)
        die "Option inconnue : $1"
        ;;
    esac
  done
}

run_on_node_env() {
  local NODE="$1"
  local SRC="$2"
  local VARS="${3:-}"
  local NAME=$(basename "$SRC")
  local LOG_FILE="$LOG_SESSION_DIR/${NODE}.log"

  printf "  %-15s | %-20s | " "$NODE" "$NAME"

  multipass transfer "$SRC" "$NODE:/tmp/$NAME"

  if multipass exec "$NODE" -- bash -c "sudo env $VARS bash /tmp/$NAME" </dev/null 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
    echo -e "\e[32m[OK]\e[0m"
  else
    echo -e "\e[31m[FAILED]\e[0m"
    echo "    ↳ Check logs: $LOG_FILE"
    return 1
  fi
}

run_on_node() {
  local NODE="$1"
  local SRC="$2"
  local NAME=$(basename "$SRC")
  local LOG_FILE="$LOG_SESSION_DIR/${NODE}.log"

  printf "  %-15s | %-20s | " "$NODE" "$NAME"

  multipass transfer "$SRC" "$NODE:/tmp/$NAME"

  if multipass exec "$NODE" -- sudo bash "/tmp/$NAME" </dev/null 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
    echo -e "\e[32m[OK]\e[0m"
  else
    echo -e "\e[31m[FAILED]\e[0m"
    echo "    ↳ Check logs: $LOG_FILE"
    return 1
  fi
}

load_versions() {
  # loading global variables to feed to the script
  get_version_info "$K8S_VERSION"
}

get_version_info() {
  local VERSION=$1
  local JSON_FILE="$SCRIPT_DIR/versions.json"

  [[ -f "$JSON_FILE" ]] || die "Fichier versions.json introuvable."
  jq -e --arg v "$VERSION" 'has($v)' "$JSON_FILE" > /dev/null \
    || die "Version '$VERSION' not found in versions.json"

  # Parse entire version block in a single jq invocation
  local assignments
  assignments=$(jq -r --arg v "$VERSION" '
    .[$v] as $ver |
    ($ver["virtual-layer"]["control-plane"]) as $cp |
    ($ver["virtual-layer"].worker) as $w |
    ($ver.kubernetes) as $k8s |
    ($ver.components["container-runtime"].containerd) as $ct |
    ($ver.components.runc) as $runc |
    ($ver.components["cni-plugin"]) as $cni |
    ($ver.components["network-plugins"].calico) as $calico |
    ($ver.components.helm) as $helm |
    ($ver.components.harbor) as $harbor |
    ($ver.components["kube-prometheus-stack"] // {}) as $prom |
    ($ver.components.argocd // {}) as $argocd |
    ($ver.components.istio // {}) as $istio |
    ($ver.components["envoy-gateway"] // {}) as $envoy |
    ($ver.tools) as $tools |
    "BASE_IMAGE=\(($ver["virtual-layer"]["base_image"] // "") | @sh)",
    "CP_PREFIX=\($cp.name | @sh)",
    "CP_NUMBER=\($cp.count | @sh)",
    "CP_OPEN_PORTS=\($cp.ports // [] | tojson | @sh)",
    "CP_OS_VERSION=\($cp["os-version"] | @sh)",
    "CP_CPUS=\($cp.cpus | @sh)",
    "CP_MEMORY=\($cp.memory | @sh)",
    "CP_DISK=\($cp.disk | @sh)",
    "CP_POD_CIDR=\($cp.cidr | @sh)",
    "W_PREFIX=\($w.name | @sh)",
    "W_NUMBER=\($w.count | @sh)",
    "W_OPEN_PORTS=\($w.ports // [] | tojson | @sh)",
    "W_OS_VERSION=\(($w["os-version"] // $w.os_version) | @sh)",
    "W_CPUS=\($w.cpus | @sh)",
    "W_MEMORY=\($w.memory | @sh)",
    "W_DISK=\($w.disk | @sh)",
    "K8S_MINOR=\($k8s.minor | @sh)",
    "K8S_PATCH=\($k8s.patch | @sh)",
    "K8S_PKG_VERSION=\($k8s.pkg_version | @sh)",
    "K8S_REPO=\($k8s.repo_url | @sh)",
    "K8S_RELEASE_KEY=\($k8s["release-key"] | @sh)",
    "CONTAINERD_VERSION=\($ct.version | @sh)",
    "CONTAINERD_URL=\($ct.url | @sh)",
    "CONTAINERD_SERVICE_URL=\($ct["service-url"] | @sh)",
    "RUNC_VERSION=\($runc.version | @sh)",
    "RUNC_URL=\($runc.url | @sh)",
    "CNI_VERSION=\($cni.version | @sh)",
    "CNI_URL=\($cni.url | @sh)",
    "CALICO_VERSION=\($calico.version | tojson | @sh)",
    "CALICO_CRD_URL=\($calico["crd-url"] | tojson | @sh)",
    "CALICO_TIGERA_OPERATOR=\($calico["tigera-operator"] | tojson | @sh)",
    "CALICO_OPEN_PORTS=\($calico.ports // [] | tojson | @sh)",
    "HELM_VERSION=\($helm.version | @sh)",
    "HELM_URL=\($helm.url | @sh)",
    "HARBOR_CHART_VERSION=\($harbor.chart_version | @sh)",
    "HARBOR_REPO_URL=\($harbor.repo_url | @sh)",
    "HARBOR_REPO_NAME=\($harbor.repo_name | @sh)",
    "HARBOR_CHART=\($harbor.chart | @sh)",
    "HARBOR_NAMESPACE=\($harbor.namespace | @sh)",
    "HARBOR_RELEASE=\($harbor.release | @sh)",
    "TOOL_HELM=\($tools.helm | tostring | @sh)",
    "TOOL_HARBOR=\($tools.harbor | tostring | @sh)",
    "TOOL_PROMETHEUS=\($tools.prometheus | tostring | @sh)",
    "TOOL_ARGOCD=\($tools.argocd | tostring | @sh)",
    "TOOL_ISTIO=\($tools.istio | tostring | @sh)",
    "TOOL_ENVOY=\($tools.envoy | tostring | @sh)",
    "PROMETHEUS_CHART_VERSION=\($prom.chart_version // "" | @sh)",
    "PROMETHEUS_REPO_URL=\($prom.repo_url // "" | @sh)",
    "PROMETHEUS_REPO_NAME=\($prom.repo_name // "" | @sh)",
    "PROMETHEUS_CHART=\($prom.chart // "" | @sh)",
    "PROMETHEUS_NAMESPACE=\($prom.namespace // "" | @sh)",
    "PROMETHEUS_RELEASE=\($prom.release // "" | @sh)",
    "ARGOCD_CHART_VERSION=\($argocd.chart_version // "" | @sh)",
    "ARGOCD_REPO_URL=\($argocd.repo_url // "" | @sh)",
    "ARGOCD_REPO_NAME=\($argocd.repo_name // "" | @sh)",
    "ARGOCD_CHART=\($argocd.chart // "" | @sh)",
    "ARGOCD_NAMESPACE=\($argocd.namespace // "" | @sh)",
    "ARGOCD_RELEASE=\($argocd.release // "" | @sh)",
    "ISTIO_VERSION=\($istio.version // "" | @sh)",
    "ISTIO_REPO_URL=\($istio.repo_url // "" | @sh)",
    "ISTIO_REPO_NAME=\($istio.repo_name // "" | @sh)",
    "ISTIO_NAMESPACE=\($istio.namespace // "" | @sh)",
    "ENVOY_CHART_VERSION=\($envoy.chart_version // "" | @sh)",
    "ENVOY_REPO_URL=\($envoy.repo_url // "" | @sh)",
    "ENVOY_NAMESPACE=\($envoy.namespace // "" | @sh)",
    "ENVOY_RELEASE=\($envoy.release // "" | @sh)"
  ' "$JSON_FILE") || die "Failed to parse versions.json for version $VERSION"

  eval "$assignments"
  CNI="calico"
}