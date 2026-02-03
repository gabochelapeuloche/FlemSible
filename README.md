# k8s-setup

Tired of setting up k8s cluster in vms on your PC ?

## Aim of the project

This project aims at making kubernetes cluster setup easier. By providing a virtual infrastructure of different vms, deploying security rules and installing the right software for a healthy running cluster. It leverages multipass and kubeadm within other softwares.

## Project tree :
.
├── all-script.sh
├── config.sh
├── lib
│   ├── kubeadm-files
│   │   ├── calico.sh
│   │   ├── cni.sh
│   │   ├── crictl2containerd.sh
│   │   ├── cri.sh
│   │   ├── disable-swap.sh
│   │   ├── init-cp.sh
│   │   ├── ipv4-forward-iptables.sh
│   │   ├── kubeconfig.sh
│   │   ├── kube.sh
│   │   └── runc.sh
│   ├── kubeadm.sh
│   ├── kube-bootstrap
│   │   ├── downgrade
│   │   ├── install
│   │   ├── uninstall
│   │   ├── update
│   │   ├── upgrade
│   │   ├── versions.csv
│   │   └── versions.json
│   ├── multipass.sh
│   ├── ufw.sh
│   ├── utils.sh
│   └── virtual-infrastructure
├── logs
│   ├── kube-bootstrap
│   ├── run
│   └── virtual-infrastructure
├── main.sh
├── README.md
└── tests
    ├── kube-bootstrap
    │   ├── calico copy.sh
    │   ├── cni.sh
    │   ├── crictl2containerd.sh
    │   ├── cri.sh
    │   ├── disable-swap.sh
    │   ├── init-cp.sh
    │   ├── ipv4-forward-iptables.sh
    │   ├── kubeconfig.sh
    │   ├── kube.sh
    │   └── runc.sh
    ├── script-config
    │   └── validate_config.sh
    └── virtual-infrastructure
        ├── infra.sh
        └── network.sh

18 directories, 33 files

##