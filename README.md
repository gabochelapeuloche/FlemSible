# FlemSible — Bash Kubernetes cluster provisioner

> One command to spin up a fully functional kubeadm Kubernetes cluster on local VMs.  
> Version-pinned, JSON-configurable, pre-baked base images, optional service stack.

![Status](https://img.shields.io/badge/status-in_development-yellow)
![Stack](https://img.shields.io/badge/stack-Bash%20%7C%20Multipass%20%7C%20Kubernetes-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What it does

FlemSible provisions Ubuntu VMs via Multipass and bootstraps a kubeadm Kubernetes cluster on top of them. It is entirely driven by `versions.json` — component versions, VM sizing, enabled services, and the base image path are all declared there. No Terraform, no Ansible, no Python.

### Cluster bootstrap sequence

1. **VMs** — Multipass VMs launched sequentially (to avoid host resource spikes), firewall configured per role
2. **Node provisioning** — all nodes provisioned in parallel; skipped entirely when a base image is used
3. **Cluster init** — `kubeadm init` on the control-plane, kubeconfig exported to host at `kubeconfig/k8s-cluster.conf`
4. **Workers join** — all workers join in parallel
5. **Calico CNI** — Tigera operator installed via manifest
6. **Optional services** — Helm installed first, then enabled tools deployed in parallel (see [Services](#optional-services))

### Base image system

The build-once/reuse model drastically reduces cluster spin-up time. A base image pre-installs everything that is identical across all nodes:

| What | Why shared |
|---|---|
| `disable-swap`, `ipv4-forward`, `iptables-bridge` | Required by kubelet on every node |
| `containerd`, `runc`, `cni-plugins` | Container runtime — same version everywhere |
| `kubeadm`, `kubelet`, `kubectl` | Kubernetes tools — same version everywhere |
| `crictl` config | Points to containerd socket on every node |
| `pause` image, `kube-proxy` image | Pulled by every node at pod scheduling time |

What is **not** pre-baked:
- Control-plane images (`kube-apiserver`, `etcd`, `scheduler`, `coredns`) — pulled at `kubeadm init` on the CP node only
- Calico images — deployed on the CP node only
- Node-specific firewall rules — differ between control-plane and workers

When `virtual-layer.base_image` is set in `versions.json`, `prepare_node` becomes a no-op: VMs boot with everything ready, provisioning is skipped entirely.

---

## Requirements

| Tool | Used for |
|---|---|
| [`multipass`](https://multipass.run/) | VM lifecycle management |
| `jq` | Parsing `versions.json` |
| `kubectl` | Post-init readiness check on the host |

---

## Quick start

The `Makefile` is the primary entry point (`make help` lists all targets):

```bash
make deploy                              # deploy cluster (default profile)
make deploy PROFILE=1.35_base ARGS="--cp-number 1 --w-number 1"
make teardown                            # delete all cluster VMs + kubeconfig
make check                               # run smoke test against running cluster
make dry-run                             # preview deploy without running anything
```

### First run (no base image)

```bash
make deploy
# or directly: ./main.sh
```

This provisions VMs from a standard Ubuntu image and installs the full stack. Slower, but requires no prior setup.

### Recommended: build a base image first

```bash
# Build once — takes ~10 minutes (downloads packages, pre-pulls images)
make build
# or directly: bash tools/build-base-image.sh 1.35_base

# Spin up clusters as many times as you want — much faster
make deploy
```

The build script registers the image path in `versions.json` automatically. Subsequent runs use it without any additional steps.

**Rebuild the base image when you change:**
- `containerd`, `runc`, or `cni-plugin` versions in `versions.json`
- `kubernetes.patch` version (affects pre-pulled images and kubeadm)

```bash
rm images/base-node-1.35_base.img
make build
```

---

## Running `main.sh`

```bash
./main.sh [options]
```

| Flag | Default | Description |
|---|---|---|
| `--profile KEY` | `1.35_base` | Profile key to look up in `versions.json` |
| `--cp-number N` | from `versions.json` | Number of control-plane nodes |
| `--w-number N` | from `versions.json` | Number of worker nodes |
| `--cpus N` | from `versions.json` | vCPUs per VM |
| `--memory XG` | from `versions.json` | RAM per VM |
| `--disk XG` | from `versions.json` | Disk per VM |
| `--clean` | | Purge any existing cluster VMs before starting |
| `--dry-run` | | Print every step without executing anything |
| `-h, --help` | | Print usage |

After completion, `kubeconfig/k8s-cluster.conf` is written and `KUBECONFIG` is exported for the current shell.

---

## Configuration — `versions.json`

All configuration lives in `versions.json`, keyed by a version string (e.g. `"1.35_base"`). The key naming convention is `<k8s-minor>_<base-os>` to make it self-describing.

```jsonc
{
  "1.35_base": {

    "cluster-name": "k8s",   // VM name prefix — VMs become k8s-control-plane-1, k8s-worker-1, …

    "virtual-layer": {
      "base_image": "/path/to/images/base-node-1.35_base.img",  // null = no base image
      "control-plane": {
        "name": "control-plane",
        "count": 1,
        "os-version": "noble",
        "cpus": 2, "memory": "2G", "disk": "15G",
        "cidr": "192.168.0.0/16",
        "ports": ["22/tcp", "6443/tcp", ...]
      },
      "worker": {
        "name": "worker",
        "count": 2,
        "cpus": 2, "memory": "2G", "disk": "15G",
        "ports": ["22/tcp", "10250/tcp", ...]
      }
    },

    "kubernetes": {
      "patch": "1.35.0",           // used by kubeadm init and image pre-pull
      "repo_url": "...",
      "release-key": "..."
    },

    "components": {
      "container-runtime": { "containerd": { "version": "...", "url": "..." } },
      "runc":              { "version": "...", "url": "..." },
      "cni-plugin":        { "version": "...", "url": "..." },
      "network-plugins":   { "calico": { "version": "...", ... } },
      "helm":              { "version": "...", "url": "..." },
      "harbor":            { "chart_version": "...", "repo_url": "...", ... },
      "kube-prometheus-stack": {
        "chart_version": "...",
        "resources": {           // memory tuning for small VMs
          "alertmanager": { "request": "64Mi",  "limit": "128Mi" },
          "prometheus":   { "request": "256Mi", "limit": "768Mi" },
          "grafana":      { "request": "64Mi",  "limit": "128Mi" }
        }
      },
      "argocd":            { "chart_version": "...", ... },
      "istio":             { "version": "...", ... },
      "envoy-gateway":     { "chart_version": "...", ... }
    },

    "tools": {
      "helm":       true,    // required if any Helm-based service is enabled
      "harbor":     true,
      "prometheus": false,
      "argocd":     false,
      "istio":      false,   // installed before other services if enabled
      "envoy":      false
    }

  }
}
```

`lib/utils.sh:get_version_info` parses the entire block into shell variables in a single `jq` call and `eval`s them into the current shell. Every script in the project consumes these variables — none hardcode versions or URLs.

---

## Optional services

Services are enabled by setting their flag to `true` in `versions.json` under `tools`. Helm must be `true` for any Helm-based service.

| Service | Flag | Chart | Notes |
|---|---|---|---|
| Helm CLI | `helm` | — | Installed on control-plane; prerequisite for all others |
| Harbor | `harbor` | `harbor/harbor` | NodePort on `:30002`; use as Docker Hub pull-through cache |
| Prometheus | `prometheus` | `kube-prometheus-stack` | Full observability stack |
| ArgoCD | `argocd` | `argo/argo-cd` | NodePort on `:30090`; insecure mode for local use |
| Istio | `istio` | `istio/base` + `istio/istiod` | Installed before other services; two sequential Helm installs |
| Envoy Gateway | `envoy` | OCI `envoyproxy/gateway-helm` | No Helm repo add required |

**Install order:** Istio (if enabled) → all others in parallel.

### Harbor after install

URL: `http://<control-plane-IP>:30002` — default credentials: `admin` / `Harbor12345` — change immediately.

After Harbor is up, `install_harbor_mirror` automatically configures `/etc/containerd/certs.d/docker.io/hosts.toml` on every node to route `docker.io` pulls through Harbor, with Docker Hub as fallback when Harbor is unreachable or the image is not cached.

To set up a proxy cache project in Harbor:
1. **Administration → Registries → New** → Docker Hub endpoint
2. **Projects → New** → enable Proxy Cache, select the endpoint

---

## Per-step timing

Every section prints its elapsed time when the next section starts, and a total is printed at the end:

```
=== VMs Spin Up ===
    ↳ 43s

=== Preparing Nodes ===
    ↳ 8s          ← near-instant with base image

=== Initializing Cluster ===
    ↳ 67s

=== Joining Workers ===
    ↳ 14s         ← parallel joins

=== Cluster ready 🎉 ===
    ↳ 12s

Total: 4m12s
```

Timing starts when `utils.sh` is sourced (script entry) and is tracked in `_SCRIPT_START`, `_SECTION_START`, and `_SECTION_NAME` shell variables. No external tools required — uses `date +%s`.

---

## Running tests

Tests are pure Bash — no external test framework required. `multipass` and `run_on_node*` are mocked so suites run without a live cluster.

```bash
bash tests/run_tests.sh
```

Output format:

```
=======================================
  Suite: kube-bootstrap/test_node_bootstrap.sh
=======================================

--- prepare_node (no base image) ---
  PASS  containerd script is run
  PASS  runc script is run
  PASS  kube script is run
  PASS  crictl config is run

--- prepare_node (with base image) ---
  PASS  no scripts are run with base image

=======================================
  12 / 12 tests passed
=======================================
```

### Test structure

| Suite | What it covers |
|---|---|
| `tests/script-config/test_utils.sh` | `get_version_info` parsing, `validate_config`, CLI arg handling |
| `tests/virtual-infrastructure/test_vm_provisioning.sh` | `create_vms`, `configure_vm`, base-image branching |
| `tests/kube-bootstrap/test_node_bootstrap.sh` | `prepare_node` (with/without base image), `join_workers` |
| `tests/kube-services/test_harbor.sh` | `install_helm`, `install_harbor`, `is_installed` guard |

---

## Project structure

```text
.
├── main.sh                              # Entry point — orchestrates the full bootstrap
├── versions.json                        # Single source of truth for all versions, URLs, flags
│
├── tools/
│   ├── build-base-image.sh              # Builds a pre-baked VM image (run once, reuse forever)
│   ├── teardown.sh                      # Deletes all cluster VMs by prefix + removes kubeconfig
│   └── check-cluster.sh                 # Smoke test: API, nodes, system pods, enabled services
│
├── images/                              # Output directory for built base images
│   └── base-node-1.35_base.img          # Generated by build-base-image.sh
│
├── kubeconfig/
│   └── k8s-cluster.conf                 # Generated after cluster init
│
├── lib/
│   ├── utils.sh                         # print_cue, die, run_on_node*, get_version_info
│   │
│   ├── virtual-infrastructure/
│   │   ├── vm-provisionning.sh          # create_vms (sequential launch), configure_vm
│   │   └── injections/                  # Scripts transferred and run on VMs
│   │       ├── network-rules.sh         # UFW port rules — differs per node role
│   │       ├── disable-swap.sh          # Baked into base image
│   │       ├── ipv4-forward.sh          # Baked into base image
│   │       └── iptables.sh              # br_netfilter + overlay — baked into base image
│   │
│   ├── kube-bootstrap/
│   │   ├── node-bootstrap.sh            # prepare_node, init_control_plane, join_workers
│   │   └── injections/
│   │       ├── containerd.sh            # Baked into base image
│   │       ├── runc.sh                  # Baked into base image
│   │       ├── cni.sh                   # Baked into base image
│   │       ├── kube.sh                  # kubeadm/kubelet/kubectl — baked into base image
│   │       ├── crictl-containerd.sh     # crictl config — baked into base image
│   │       ├── kubeadm-init.sh          # Control-plane only — NOT baked
│   │       ├── calico.sh                # Control-plane only — NOT baked
│   │       ├── helm.sh                  # Control-plane only
│   │       └── host-config.sh           # Copies kubeconfig to host
│   │
│   └── kube-services/
│       ├── harbor.sh                    # install_harbor (host-side orchestration)
│       ├── prometheus.sh                # install_prometheus
│       ├── argocd.sh                    # install_argocd
│       ├── istio.sh                     # install_istio
│       ├── envoy.sh                     # install_envoy
│       └── injections/                  # Run on control-plane via run_on_node_env
│           ├── harbor.sh
│           ├── configure-harbor-mirror.sh  # Patches hosts.toml on every node post-install
│           ├── prometheus.sh
│           ├── argocd.sh
│           ├── istio.sh                 # Two sequential helm installs (base then istiod)
│           └── envoy.sh                 # OCI chart — no helm repo add needed
│
├── tests/
│   ├── run_tests.sh                     # Runs all suites, reports total pass/fail
│   ├── lib/helpers.sh                   # assert_eq, assert_true, assert_contains, etc.
│   ├── script-config/test_utils.sh
│   ├── virtual-infrastructure/test_vm_provisioning.sh
│   ├── kube-bootstrap/test_node_bootstrap.sh
│   └── kube-services/test_harbor.sh
│
└── logs/                                # Per-run session logs
    ├── run_20260408_120000/
    │   ├── k8s-control-plane-1.log      # Node-level logs (kubeadm init, joins, …)
    │   ├── k8s-worker-1.log
    │   ├── harbor.log                   # Per-service logs (parallel installs — no interleaving)
    │   ├── prometheus.log
    │   ├── harbor-mirror-k8s-worker-1.log
    │   └── …
    └── build_20260408_110000/           # Base image build logs
```

---

## How scripts are deployed to nodes

All node-side work follows the same pattern:

```
host                                    VM node
─────                                   ───────
run_on_node_env "$NODE" script.sh  →    multipass transfer → /tmp/script.sh
  "VAR1=val VAR2=val"               →    sudo env VAR1=val VAR2=val bash /tmp/script.sh
```

- `run_on_node_env` — transfers script + injects env vars at execution time; optional 4th arg overrides the log file path
- `run_on_node` — transfers and runs without env vars; optional 3rd arg overrides the log file path
- Default log: `$LOG_SESSION_DIR/<node>.log`; service installs pass a per-service file (e.g. `harbor.log`) to avoid interleaving in parallel runs

Every injection script is self-contained and idempotent: it checks `is_installed()` or `is_applied()` before doing any work. This means re-running is safe, and when a base image is used, the checks pass immediately and the script exits without side effects.

---

## Key implementation details (for contributors and AI agents)

- **Variable injection**: `lib/utils.sh:get_version_info` parses `versions.json` in a single `jq` call and `eval`s the result. All downstream scripts consume these variables — never parse `versions.json` directly elsewhere.
- **Base image branching**: `$BASE_IMAGE` (empty string = no base image). `vm-provisionning.sh:create_vms` uses `file://$BASE_IMAGE` as the Multipass launch image when set. `node-bootstrap.sh:prepare_node` skips the entire provisioning block when `BASE_IMAGE` is non-empty.
- **Role distinction**: control-plane and workers share the same base image. Node-role-specific work (firewall rules, `kubeadm init`, service installs) always targets named VMs explicitly.
- **Parallelism boundaries**: VM launches are sequential (resource constraint). Node provisioning is parallel across nodes. Worker joins are parallel. Service installs are parallel (Istio first if enabled).
- **No persistent state on VMs**: env vars are injected at script execution time. VMs hold no configuration beyond what the scripts write to disk.
