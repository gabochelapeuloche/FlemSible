#!/usr/bin/env bash

# Cluster
CP_NUMBER=1
W_NUMBER=2
CP_PREFIX=control-plane
W_PREFIX=worker

# VM
OS_VERSION="noble"
CPUS=2
MEMORY=2G
DISK=15G
NETWORK=""

# Kubernetes
K8S_VERSION="v1.29"
POD_CIDR="192.168.0.0/16"
CNI="calico"

# Options
VERBOSE=false
SNAPSHOT=false
CONNEXION_TEST=true
SET_UP_TEST=true