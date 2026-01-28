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