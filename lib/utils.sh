#!/usr/bin/env bash

: '
Utilities for logging, error handling and CLI parsing
'

# Logging (verbose only)
log() {
  [[ "${VERBOSE:-false}" == true ]] || return 0
  printf "%b\n" "$*"
}

section() {
  log ""
  log "=== $* ==="
}

# Error handling
die() {
  printf "❌ %b\n" "$*" >&2
  exit 1
}

# Requirements
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
