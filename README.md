# 🤖 FlemSible — Bash k8s cluster provider

> A scripting solution for spinning up full kubeadm and functional kubernetes clusters.  
> One command, json customizable.

![Status](https://img.shields.io/badge/status-in_development-yellow)
![Stack](https://img.shields.io/badge/stack-Bash%20%7C%20Multipass%20%7C%20Kubernetes%20%7C%20MCP-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

# FlemSibe - K8S Cluster Provider

Tired of setting up k8s cluster in vms on my PC, not wanting to use terraform and ansible right now. This is a bash script that provides vms (leveraging multipass ubuntu) and performs cli actions on them to boot up a kubernetes cluster.

## Aim of the project

This project aims at making kubernetes cluster setup easier. By providing a virtual infrastructure of different vms, deploying security rules and installing the right software for a healthy running cluster. It leverages multipass and kubeadm within other softwares.

How does it do ?

1. A json file containing all versions and urls to download tools and utility is parsed. This fil can be used to create custom versions

2. Our script collect data from the json file and stock them in global variables

3. Vms are provided with multipass

4. Configuration scripts are send to vms depending on the future role of the node they'll host, with when it's necessary configuration variables (temporary environment affectations). On the different nodes, the script are executed for preparing the kube adm initialization or joining process.

5. Once Control plane is up and running
    - scrap the join command
    - scrap the kubeconfig
    - join workers
    - set kubeconfig

6. Install Calico

## Project tree

.
├── kubeconfig
│   └── k8s-cluster.conf
├── lib
│   ├── kube-bootstrap
│   │   ├── injections
│   │   │   ├── calico.sh
│   │   │   ├── cni.sh
│   │   │   ├── containerd.sh
│   │   │   ├── crictl-containerd.sh
│   │   │   ├── host-config.sh
│   │   │   ├── kubeadm-init.sh
│   │   │   ├── kube.sh
│   │   │   └── runc.sh
│   │   └── node-bootstrap.sh
│   ├── kube-services
│   ├── utils.sh
│   └── virtual-infrastructure
│       ├── injections
│       │   ├── disable-swap.sh
│       │   ├── iptables.sh
│       │   ├── ipv4-forward.sh
│       │   └── network-rules.sh
│       └── vm-provisionning.sh
├── logs
├── main.sh
├── README.md
├── tests
│   ├── kube-bootstrap
│   ├── script-config
│   └── virtual-infrastructure
└── versions.json

13 directories, 19 files

## command to run the script

You'll probably need to run chmod +x to give execution right to main.sh. Then just run ./main "version" and it's done. If the script is not broken you'll have a k8s running cluster with cni plugin.

## Options