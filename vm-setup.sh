#!/bin/bash/

### Setup vms with multipass ###


# $1 number of control planes
# $2 number of worker-nodes

for 

# Lancer les vms en attachant le bridge
# Script pour créer 3 VMs Kubernetes

# Lancer les VMs
for NODE in master worker1 worker2; do
  multipass launch noble \
  --name $NODE \
  --cpus 2 \
  --memory 3G \
  --disk 20G \
  --network br-datalake
done

# Tester la communication entre vms
multipass exec master -- ping -c 3 $W1_IP
echo -e "\n\n\n---"
multipass exec master -- ping -c 3 $W2_IP
echo -e "\n\n\n---"
multipass exec worker1 -- ping -c 3 $M_IP
echo -e "\n\n\n---"
multipass exec worker1 -- ping -c 3 $W2_IP
echo -e "\n\n\n---"
multipass exec worker2 -- ping -c 3 $M_IP
echo -e "\n\n\n---"
multipass exec worker2 -- ping -c 3 $W1_IP
echo -e "\n\n\n"





for NODE in master worker1 worker2; do
  multipass stop $NODE
  multipass snapshot $NODE --name $NODE-bare --comment "instance before kube installation"
  multipass start $NODE
done
