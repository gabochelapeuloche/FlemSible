#!/usr/bin/env bash

: '
  This bash file contains utilities used for running the programm smoothly
  and log the process.
'

set -Eeuo pipefail

# A function that prints informations when --verbose option is used
log() {
  [[ "$VERBOSE" == true ]] || return 0
  printf "%b\n" "$*"
}

# A function that prints an error then exits the program
die() {
  echo "❌ $*" >&2
  exit 1
}

# A function that tests for requirements
require_cmd() {
  command -v "$1" &>/dev/null || die "$1 n'est pas installé"
}

# A function that gathers users parameters for customization
user_inputs() {
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
}