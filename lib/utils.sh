#!/usr/bin/env bash
# =============================================================================
# lib/utils.sh — Shared utilities: logging, timing, error handling, CLI
#                parsing, node execution, and version config loading.
#
# Sourced by: main.sh, tools/build-base-image.sh
# Exports:    print_cue, section, print_total_time, die, require_cmd,
#             is_number, is_storage, validate_config, usage, user_inputs,
#             run_on_node_env, run_on_node, get_version_info
# =============================================================================

# print_cue [message...]
# Print a human-readable status line to stdout.
# Reserved for script state and UI output — not for per-node logs.
print_cue() {
  printf "%b\n" "$*"
}

# ---------------------------------------------------------------------------
# Timing — state variables set when utils.sh is sourced (i.e. at script start)
# ---------------------------------------------------------------------------
_SCRIPT_START=$(date +%s)
_SECTION_START=0
_SECTION_NAME=""

# section [name...]
# Print a named section header. Prints elapsed seconds for the previous
# section before opening the new one.
# Globals: _SECTION_START (rw), _SECTION_NAME (rw)
section() {
  local now
  now=$(date +%s)

  if [[ -n "$_SECTION_NAME" && "$_SECTION_START" -gt 0 ]]; then
    printf "    ↳ %ds\n" "$(( now - _SECTION_START ))"
  fi

  _SECTION_START=$now
  _SECTION_NAME="$*"
  print_cue ""
  print_cue "=== $* ==="
}

# print_total_time
# Close the last open section and print total elapsed time since script start.
# Called once at the end of main.sh.
# Globals: _SCRIPT_START (r), _SECTION_START (rw), _SECTION_NAME (r)
print_total_time() {
  local now elapsed
  now=$(date +%s)
  if [[ -n "$_SECTION_NAME" && "$_SECTION_START" -gt 0 ]]; then
    printf "    ↳ %ds\n" "$(( now - _SECTION_START ))"
    _SECTION_START=0
  fi
  elapsed=$(( now - _SCRIPT_START ))
  printf "\nTotal: %dm%02ds\n" "$(( elapsed / 60 ))" "$(( elapsed % 60 ))"
}

# die [message...]
# Print an error message to stderr and exit with code 1.
die() {
  printf "❌ %b\n" "$*" >&2
  exit 1
}

# drun [command...]
# Execute a command normally, or print it prefixed with [DRY-RUN] when DRY_RUN=true.
# Globals: DRY_RUN (r)
drun() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    printf "  \e[33m[DRY-RUN]\e[0m %s\n" "$*"
    return 0
  fi
  "$@"
}

# require_cmd [command]
# Assert that a command is available on the host; die if not.
require_cmd() {
  command -v "$1" &>/dev/null || die "$1 n'est pas installé"
}

# is_number [value]
# Return 0 if value is a non-negative integer, 1 otherwise.
is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# is_storage [value]
# Return 0 if value matches the XM or XG storage format (e.g. 2G, 512M).
is_storage() {
  [[ "$1" =~ ^[0-9]+[MG]$ ]]
}

# validate_config
# Assert that the required cluster size variables are within valid bounds.
# Globals: CP_NUMBER (r), W_NUMBER (r)
validate_config() {
  [[ "$CP_NUMBER" -ge 1 ]] || die "CP_NUMBER must be >= 1"
  [[ "$W_NUMBER" -ge 0 ]] || die "W_NUMBER must be >= 0"
}

# usage
# Print CLI usage to stdout.
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --profile KEY   Profile key in versions.json (default: 1.35_base)
  --cp-number N   Number of control-plane nodes
  --w-number N    Number of worker nodes
  --cpus N        vCPUs per VM
  --memory XG     RAM per VM (e.g. 2G)
  --disk XG       Disk per VM (e.g. 15G)
  --network NAME  Multipass network name
  --verbose       Enable verbose output
  --dry-run       Print what would be executed without running anything
  --clean         Purge any existing cluster VMs before starting
  -h, --help      Show this help
EOF
}

# user_inputs [args...]
# Parse CLI flags and store overrides in *_USER variables.
# Values are applied after get_version_info so they take precedence.
user_inputs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --profile)
        PROFILE="$2"
        shift 2
        ;;
      --cp-number)
        CP_NUMBER_USER="$2"
        is_number "$CP_NUMBER_USER" || die "CP_NUMBER doit être un entier"
        shift 2
        ;;
      --w-number)
        W_NUMBER_USER="$2"
        is_number "$W_NUMBER_USER" || die "W_NUMBER doit être un entier"
        shift 2
        ;;
      --cpus)
        CPUS_USER="$2"
        is_number "$CPUS_USER" || die "CPUS doit être un entier"
        shift 2
        ;;
      --memory)
        MEMORY_USER="$2"
        is_storage "$MEMORY_USER" || die "MEMORY doit être de la forme XG"
        shift 2
        ;;
      --disk)
        DISK_USER="$2"
        is_storage "$DISK_USER" || die "DISK doit être de la forme XG"
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
      --dry-run)
        export DRY_RUN=true
        shift
        ;;
      --clean)
        export CLEAN=true
        shift
        ;;
      *)
        die "Option inconnue : $1"
        ;;
    esac
  done
}

# run_on_node_env [node] [script_path] [env_vars] [log_file]
# Transfer a script to a VM and execute it with injected environment variables.
# Output is logged to $LOG_SESSION_DIR/<node>.log (or [log_file] if provided);
# console shows [OK]/[FAILED].
# Arguments: $1 = VM name, $2 = local script path, $3 = "VAR=val VAR2=val2",
#            $4 = optional log file path override
# Globals: LOG_SESSION_DIR (r)
run_on_node_env() {
  local NODE="$1"
  local SRC="$2"
  local VARS="${3:-}"
  local LOG_FILE="${4:-$LOG_SESSION_DIR/${NODE}.log}"
  local NAME
  NAME=$(basename "$SRC")

  printf "  %-15s | %-20s | " "$NODE" "$NAME"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    echo -e "\e[33m[DRY-RUN]\e[0m"
    return 0
  fi

  multipass transfer "$SRC" "$NODE:/tmp/$NAME"

  if multipass exec "$NODE" -- bash -c "sudo env $VARS bash /tmp/$NAME" </dev/null 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
    echo -e "\e[32m[OK]\e[0m"
  else
    echo -e "\e[31m[FAILED]\e[0m"
    echo "    ↳ Check logs: $LOG_FILE"
    return 1
  fi
}

# run_on_node [node] [script_path] [log_file]
# Transfer a script to a VM and execute it without extra environment variables.
# Arguments: $1 = VM name, $2 = local script path,
#            $3 = optional log file path override
# Globals: LOG_SESSION_DIR (r)
run_on_node() {
  local NODE="$1"
  local SRC="$2"
  local LOG_FILE="${3:-$LOG_SESSION_DIR/${NODE}.log}"
  local NAME
  NAME=$(basename "$SRC")

  printf "  %-15s | %-20s | " "$NODE" "$NAME"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    echo -e "\e[33m[DRY-RUN]\e[0m"
    return 0
  fi

  multipass transfer "$SRC" "$NODE:/tmp/$NAME"

  if multipass exec "$NODE" -- sudo bash "/tmp/$NAME" </dev/null 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
    echo -e "\e[32m[OK]\e[0m"
  else
    echo -e "\e[31m[FAILED]\e[0m"
    echo "    ↳ Check logs: $LOG_FILE"
    return 1
  fi
}

# get_version_info [version_key]
# Parse the versions.json block for the given key and eval all variables
# into the current shell in a single jq pass.
# Arguments: $1 = key in versions.json (e.g. "1.35_base")
# Globals:   SCRIPT_DIR (r), exports all CP_*, W_*, K8S_*, CONTAINERD_*,
#            RUNC_*, CNI_*, CALICO_*, HELM_*, HARBOR_*, TOOL_*, and
#            chart config variables for each optional service.
get_version_info() {
  local VERSION=$1
  local JSON_FILE="$SCRIPT_DIR/versions.json"

  [[ -f "$JSON_FILE" ]] || die "Fichier versions.json introuvable."
  jq -e --arg v "$VERSION" 'has($v)' "$JSON_FILE" > /dev/null \
    || die "Version '$VERSION' not found in versions.json"

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
    "CLUSTER_NAME=\($ver["cluster-name"] | @sh)",
    "CP_PREFIX=\("\($ver["cluster-name"])-\($cp.name)" | @sh)",
    "CP_NUMBER=\($cp.count | @sh)",
    "CP_OPEN_PORTS=\($cp.ports // [] | tojson | @sh)",
    "CP_OS_VERSION=\($cp["os-version"] | @sh)",
    "CP_CPUS=\($cp.cpus | @sh)",
    "CP_MEMORY=\($cp.memory | @sh)",
    "CP_DISK=\($cp.disk | @sh)",
    "CP_POD_CIDR=\($cp.cidr | @sh)",
    "W_PREFIX=\("\($ver["cluster-name"])-\($w.name)" | @sh)",
    "W_NUMBER=\($w.count | @sh)",
    "W_OPEN_PORTS=\($w.ports // [] | tojson | @sh)",
    "W_OS_VERSION=\($w["os-version"] | @sh)",
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
    "PROMETHEUS_ALERTMANAGER_MEM_REQUEST=\($prom.resources.alertmanager.request // "64Mi" | @sh)",
    "PROMETHEUS_ALERTMANAGER_MEM_LIMIT=\($prom.resources.alertmanager.limit // "128Mi" | @sh)",
    "PROMETHEUS_MEM_REQUEST=\($prom.resources.prometheus.request // "256Mi" | @sh)",
    "PROMETHEUS_MEM_LIMIT=\($prom.resources.prometheus.limit // "768Mi" | @sh)",
    "PROMETHEUS_GRAFANA_MEM_REQUEST=\($prom.resources.grafana.request // "64Mi" | @sh)",
    "PROMETHEUS_GRAFANA_MEM_LIMIT=\($prom.resources.grafana.limit // "128Mi" | @sh)",
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
