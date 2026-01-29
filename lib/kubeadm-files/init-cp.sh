sudo kubeadm init \
  --apiserver-advertise-address="$CP_IP" \
  --pod-network-cidr="$POD_CIDR" \
  --node-name master