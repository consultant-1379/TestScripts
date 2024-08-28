#!/bin/bash

printf "\n============================================================================ \n\n"
printf "kubectl version installed on the client machine \n"
kubectl version --short --client
printf "\n============================================================================ \n\n"

printf "Docker version installed on the client machine \n"
sudo docker version --format '{{.Client.Version}}'
printf "\n============================================================================ \n\n"

printf "helm version installed on the client machine ----- must be 3.2.1 or higher. \n"
helm version --client --short
printf "\n============================================================================ \n\n"

printf "Verify the cluster info for cENM deployment is correct \n"
kubectl cluster-info
printf "\n============================================================================ \n\n"

printf "Verify the cluster control plane component status \n"
kubectl get componentstatuses
printf "\n============================================================================ \n\n"

printf "Verify the status and version of all the nodes. All worker nodes must be in Ready state \n"
kubectl get nodes
printf "\n============================================================================ \n\n"

printf "Ensure that the cENM namespace is listed correctly \n"
kubectl get namespaces | grep -i enm4
printf "\n============================================================================ \n\n"

printf "Verify that the Docker version installed on the cluster \n"
sudo docker version --format '{{.Server.Version}}'
printf "\n============================================================================ \n\n"

printf "Verify that the taint is correctly applied on the two worker nodes that are used for the LVS service group scheduling \n"
kubectl describe nodes | egrep "Taint|Hostname" | grep -A 1 routing 
printf "\n============================================================================ \n\n"

printf "Verify that the node selector is applied on LVS worker nodes and the node status is ready. \n"
kubectl get nodes --show-labels -l node=ericingress
printf "\n============================================================================ \n\n"

printf "Current helm chart Status information \n"
helm list --date --namespace enm4
printf "\n============================================================================ \n\n"

printf "Verify the READY status of the statefulset objects \n"
kubectl get statefulsets -n enm4
printf "\n============================================================================ \n\n"

printf "Verify that all the pods are in a Running state \n"
kubectl get pod -n enm4 
printf "\n============================================================================ \n\n"

printf "List of restarted pods \n"
kubectl get pods| awk '($4 != "0")'
printf "\n============================================================================ \n\n"

printf "Verify that there is no running CronJob \n"
kubectl get cronjobs -n enm4
printf "\n============================================================================ \n\n"

printf "Verify that all PVC are in bound state \n"
kubectl get pvc -n enm4
printf "\n============================================================================ \n\n"

printf "Verify that all the Jobs are in a completed state \n"
kubectl get jobs -n enm4
printf "\n============================================================================ \n\n"

