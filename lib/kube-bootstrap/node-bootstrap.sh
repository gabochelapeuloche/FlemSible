#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/node-bootstrap.sh — Kubernetes cluster bootstrap logic.
#
# Handles per-node runtime installation, control-plane initialisation,
# worker join, and Calico CNI deployment. All functions run from the host
# and delegate work to injection scripts via run_on_node / run_on_node_env.
#
# Sourced by: main.sh
# Globals consumed: CP_PREFIX, W_PREFIX, VMS, BASE_IMAGE, K8S_PATCH,
#                   K8S_REPO, K8S_RELEASE_KEY, CP_POD_CIDR, SCRIPT_DIR,
#                   CONTAINERD_*, RUNC_*, CNI_*, CALICO_*
# =============================================================================

# prepare_node [node_name]
# Install the Kubernetes runtime stack on a single node. When BASE_IMAGE is
# set the image already contains containerd, runc, cni, kubeadm, kubelet,
# kubectl, and crictl — the function is a no-op in that case.
# When no base image is used, all components are installed in parallel.
# Arguments: $1 = VM name
# Globals: BASE_IMAGE (r), SCRIPT_DIR (r), CONTAINERD_* (r), RUNC_* (r),
#          CNI_* (r), K8S_* (r)
prepare_node() {
  local NODE="$1"

  print_cue "Preparing node $NODE"

  if [[ -z "${BASE_IMAGE:-}" ]]; then
    # No pre-baked image — install full runtime stack in parallel
    run_on_node_env "$NODE" \
      "$SCRIPT_DIR/lib/kube-bootstrap/injections/containerd.sh" \
      "VERSION=$CONTAINERD_VERSION CHECK_SUM_URL=$CONTAINERD_URL SERVICE_URL=$CONTAINERD_SERVICE_URL" &

    run_on_node_env "$NODE" \
      "$SCRIPT_DIR/lib/kube-bootstrap/injections/runc.sh" \
      "VERSION=$RUNC_VERSION URL=$RUNC_URL" &

    run_on_node_env "$NODE" \
      "$SCRIPT_DIR/lib/kube-bootstrap/injections/cni.sh" \
      "VERSION=$CNI_VERSION URL=$CNI_URL" &

    run_on_node_env "$NODE" \
      "$SCRIPT_DIR/lib/kube-bootstrap/injections/kube.sh" \
      "VERSION=$K8S_PATCH URL=$K8S_REPO RELEASE_KEY=$K8S_RELEASE_KEY" &

    wait

    # crictl config runs after kube packages (provides the crictl binary)
    run_on_node_env "$NODE" \
      "$SCRIPT_DIR/lib/kube-bootstrap/injections/crictl-containerd.sh" \
      ""
  fi
  # With base image: containerd, runc, cni, kubeadm/kubelet/kubectl, and
  # crictl are all pre-installed — nothing to do here.
}

# init_control_plane
# Run kubeadm init on the first control-plane node and copy the admin
# kubeconfig into the ubuntu user's home directory for in-VM kubectl access.
# Globals: CP_PREFIX (r), CP_POD_CIDR (r), SCRIPT_DIR (r)
init_control_plane() {
  local NODE_NAME="${CP_PREFIX}-1"
  local CP_IP

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    CP_IP="<vm-ip>"
  else
    CP_IP=$(multipass exec "$NODE_NAME" -- hostname -I | awk '{print $1}')
  fi

  print_cue "Initializing control-plane on $NODE_NAME ($CP_IP)"

  run_on_node_env "$NODE_NAME" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/kubeadm-init.sh" \
    "POD_CIDR=$CP_POD_CIDR"

  # Make kubeconfig accessible to the ubuntu user inside the VM
  drun multipass exec "$NODE_NAME" -- bash -c \
    'mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config && chmod 600 $HOME/.kube/config'
}

# join_workers
# Generate a kubeadm join token on the control-plane and apply it to all
# worker nodes in parallel. Skips the control-plane VM itself.
# Globals: CP_PREFIX (r), VMS (r)
join_workers() {
  local CP_NODE="$CP_PREFIX-1"
  local JOIN_CMD

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    JOIN_CMD="kubeadm join <cp-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
  else
    JOIN_CMD=$(multipass exec "$CP_NODE" -- sudo kubeadm token create --print-join-command)
  fi

  for NODE in "${VMS[@]}"; do
    [[ "$NODE" == "$CP_NODE" ]] && continue
    (
      local_log="$LOG_SESSION_DIR/${NODE}.log"
      printf "  %-15s | %-20s | " "$NODE" "kubeadm join"
      if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "\e[33m[DRY-RUN]\e[0m"
        exit 0
      fi
      if multipass exec "$NODE" -- sudo bash -c "$JOIN_CMD" </dev/null 2>&1 \
          | tee -a "$local_log" > /dev/null; then
        echo -e "\e[32m[OK]\e[0m"
      else
        echo -e "\e[31m[FAILED]\e[0m"
        echo "    ↳ Check logs: $local_log"
        exit 1
      fi
    ) &
  done
  wait
}

# install_calico_operator
# Deploy the Tigera operator and Calico custom resources on the control-plane.
# Globals: CP_PREFIX (r), CALICO_VERSION (r), CALICO_TIGERA_OPERATOR (r),
#          CALICO_CRD_URL (r), SCRIPT_DIR (r)
install_calico_operator() {
  local CP_NODE="${CP_PREFIX}-1"

  print_cue "Installing Calico (Tigera Operator) on $CP_NODE"

  run_on_node_env "$CP_NODE" \
    "$SCRIPT_DIR/lib/kube-bootstrap/injections/calico.sh" \
    "VERSION=$CALICO_VERSION OPERATOR_URL=$CALICO_TIGERA_OPERATOR CUSTOM_RESOURCES_URL=$CALICO_CRD_URL"
}
