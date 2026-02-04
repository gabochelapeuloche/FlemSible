# k8s-setup

Tired of setting up k8s cluster in vms on your PC ?

## Aim of the project

This project aims at making kubernetes cluster setup easier. By providing a virtual infrastructure of different vms, deploying security rules and installing the right software for a healthy running cluster. It leverages multipass and kubeadm within other softwares.

## Project tree

.
├── config.sh
├── kubeconfig
│   └── test.conf
├── lib
│   ├── kubeadm.sh
│   ├── kube-bootstrap
│   │   └── install
│   │       ├── calico.sh
│   │       ├── cni.sh
│   │       ├── containerd.sh
│   │       ├── crictl-containerd.sh
│   │       ├── host-config.sh
│   │       ├── init-cp.sh
│   │       ├── kube.sh
│   │       └── runc.sh
│   ├── multipass.sh
│   ├── utils.sh
│   └── virtual-infrastructure
│       ├── disable-swap.sh
│       ├── iptables.sh
│       ├── ipv4-forward.sh
│       └── network-rules.sh
├── logs
│   ├── kube-bootstrap
│   ├── run
│   └── virtual-infrastructure
├── main.sh
├── README.md
├── tests
│   ├── kube-bootstrap
│   │   ├── calico.sh
│   │   ├── cni.sh
│   │   ├── containerd.sh
│   │   ├── crictl-containerd.sh
│   │   ├── init-cp.sh
│   │   ├── iptables.sh
│   │   ├── ipv4-forward.sh
│   │   ├── kubeconfig.sh
│   │   ├── kube.sh
│   │   ├── runc.sh
│   │   └── swapp.sh
│   ├── script-config
│   │   └── validate_config.sh
│   └── virtual-infrastructure
│       ├── infra.sh
│       └── network.sh
└── versions.json

14 directories, 34 files
