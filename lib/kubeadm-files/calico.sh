#!/usr/bin/env bash
set -Eeuo pipefail

# Installer l'opérateur (CRDs incluses) SANS apply
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml || true

# Attendre que l'opérateur soit prêt
kubectl rollout status deployment/tigera-operator -n tigera-operator --timeout=120s

# Installer les custom resources
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
