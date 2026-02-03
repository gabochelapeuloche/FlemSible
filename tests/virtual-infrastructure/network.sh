# script testing connection between vms and connection between vms and public internet

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