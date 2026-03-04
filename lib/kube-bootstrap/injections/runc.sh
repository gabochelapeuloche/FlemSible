# Performing runc installation on both control-plane and worker nodes
#!/usr/bin/env bash
set -Eeuo pipefail

# Arguments to feed before injecting script into the nodes
VERSION="${VERSION:-}"
URL="${URL:-}"

# Hard coded args
COMPONENT="runc"

BIN_PATH="/usr/local/sbin/runc"

is_installed() {
  [[ -x "$BIN_PATH" ]]
}

install() {
  echo "[$COMPONENT] installing version $VERSION"

  curl -fsSLO "$URL"
  sudo install -m 755 runc.amd64 "$BIN_PATH"
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"