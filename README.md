# k8s-setup

Tired of setting up k8s cluster in vms on your PC ?

## Aim of the project

This project aims at making kubernetes cluster setup easier. By providing a virtual infrastructure of different vms, deploying security rules and installing the right software for a healthy running cluster. It leverages multipass and kubeadm within other softwares.

## Project tree :
.
├── config.sh
├── lib
│   ├── kubeadm-files
│   │   ├── calico.sh
│   │   ├── cni.sh
│   │   ├── crictl2containerd.sh
│   │   ├── cri.sh
│   │   ├── disable-swap.sh
│   │   ├── init-cp.sh
│   │   ├── ipv4-forward-iptables.sh
│   │   ├── kubeconfig.sh
│   │   ├── kube.sh
│   │   └── runc.sh
│   ├── kubeadm.sh
│   ├── multipass.sh
│   ├── ufw.sh
│   └── utils.sh
├── main.sh
└── README.md

##