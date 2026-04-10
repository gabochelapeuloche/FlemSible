# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FlemSible** provisions local Kubernetes clusters on Multipass VMs using pure Bash + kubeadm. No Python, Terraform, or Ansible. All component versions and configuration live in `versions.json` as a single source of truth.

## Commands

The `Makefile` is the primary entry point (`make help` lists all targets):

```bash
make deploy                        # deploy cluster with default profile (1.35_base)
make deploy PROFILE=1.35_base ARGS="--cp-number 1 --w-number 1"
make build                         # build pre-baked base image
make teardown                      # delete all cluster VMs + kubeconfig
make check                         # run smoke test against running cluster
make test                          # run unit test suite
make dry-run                       # preview deploy without running anything
```

Direct script usage:

```bash
./main.sh [--profile <key>] [--cp-number N] [--w-number N] [--memory Xg] [--dry-run]
bash tools/build-base-image.sh <profile>
bash tools/teardown.sh [--profile <key>]
bash tools/check-cluster.sh [--profile <key>]
bash tests/run_tests.sh
bash tests/script-config/test_utils.sh   # run a single suite
```

## Architecture

### Configuration loading

`versions.json` is the only config file. Each top-level key is a profile (e.g., `"1.35_base"`). `get_version_info <profile>` in `lib/utils.sh` parses the entire profile with a single `jq` call and `eval`s 40+ shell variables (`CP_*`, `W_*`, `K8S_*`, `CONTAINERD_*`, `TOOL_*`, etc.) into the calling shell. No downstream script parses JSON — they only consume those variables.

### Host-orchestration + node-injection pattern

All VM-side work follows one pattern:

```
Host script (lib/**/*.sh)        →  multipass transfer + run_on_node_env
Injection script (lib/**/injections/*.sh)  →  runs inside VM via sudo env bash
```

`run_on_node_env "$NODE" "/path/to/script.sh" "VAR1=val VAR2=val"` transfers the script, then executes it with injected env vars. No persistent state is left on VMs.

### Execution flow in main.sh

```
user_inputs → get_version_info → validate_config
→ create_vms (sequential launches, parallel configure_vm)
→ prepare_node [parallel] (no-op if BASE_IMAGE is set)
→ init_control_plane → export_kubeconfig_to_host
→ join_workers [parallel]
→ install_helm (if enabled)
→ install_calico_operator
→ wait: all nodes Ready + Calico Running
→ install_istio (first, if enabled)
→ install_harbor / install_prometheus / install_argocd / install_envoy [parallel background]
→ print_total_time
```

### Base image system

`tools/build-base-image.sh` builds a reusable Ubuntu Minimal image with the full runtime stack pre-installed (containerd, runc, cni, kubeadm/kubelet/kubectl, pause + kube-proxy images). When `versions.json` has a `base_image` path, `create_vms` launches from that image and `prepare_node` is skipped entirely.

### Optional services

Services are gated by `tools.*` boolean flags in `versions.json`. Each service follows the same pattern: a host-side orchestration script in `lib/kube-services/` sources and calls a node-side injection script in `lib/kube-services/injections/` via Helm.

### Test framework

`tests/lib/helpers.sh` provides a minimal assert library with no external dependencies (`assert_eq`, `assert_contains`, `assert_file_contains`, `assert_succeeds`, `assert_fails`, etc.). Tests mock `multipass` and `run_on_node_env` functions in-process so suites run without a live cluster. `tests/run_tests.sh` aggregates all suites and exits 1 on any failure.

## Known bugs (from CLAUDECONTRIBUTE.md)

check bugs and improvment planned directly in the file `CLAUDECONTRIBUTE.md`.

## Key conventions

- `section "Name"` starts a named phase and prints elapsed time for the previous phase. Use it for every logical step in `main.sh`.
- `die "message"` prints an error and exits 1. Use it for fatal precondition failures.
- `print_cue "$NODE" "OK|FAILED"` is the standard per-VM status line.
- The ERR trap in `main.sh` calls `cleanup()` which purges all VMs in `${VMS[@]}`.
- All node-side scripts must be idempotent — `is_installed()` guards are expected.
