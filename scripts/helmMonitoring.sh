#!/bin/bash

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2019 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

export PATH=$PATH:/usr/local/bin
export HOME=/root
export KUBECONFIG=/home/ec2-user/.kube/config

usage() {
  echo "$0 <usage>"
  echo " "
  echo "options:"
  echo -e "--help \t Show options for this script"
  echo -e "--install \t Install a monitoring charts"
}

if [ $# -lt 1 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --install)
              INSTALL="true";
              shift
              ;;
          --)
              break
              ;;
          *)
              break
              ;;
      esac
  done

  if [ "$INSTALL" = "true" ]; then
    echo "Installing Metrics Server and Kubernets Dashboard..."
    # metrics server installation 
    helm install stable/metrics-server \
      --name metrics-server \
      --namespace kube-system
    if [[ $? -ne 0 ]] ; then
    exit 1
    fi
    # wait for a minute then run:
    # kubectl top pods --all-namespaces
    # kubectl top pods 
    

    # k8s dashboard installation
    helm install stable/kubernetes-dashboard \
      --name kubernetes-dashboard \
      --namespace kube-system
    if [[ $? -ne 0 ]] ; then
    exit 1
    fi
    # to access run:
    # from bastion: kubectl -n kube-system port-forward svc/kubernetes-dashboard 8443:443 &
    # from bastion: aws-iam-authenticator token --token-only -i $(tail -1 ~/.kube/config |tr -d '\ '|sed -e 's/^-//g')
    # from your workstation: ssh -f ec2-user@3.93.233.228 -L 8443:localhost:8443 -N
    # from your workstation: open https://localhost:8443 in your browser

    # WeaveScope installation
    helm install stable/weave-scope \
    --name weave-scope \
    --namespace kube-system
    if [[ $? -ne 0 ]] ; then
    exit 1
    fi
  fi

  STATUS_MS=$(helm ls metrics-server | grep metrics-server | awk '{print $8}')
  while [ "$STATUS_MS" != "DEPLOYED" ]; do
    echo "Metrics Server is still deploying, sleeping for a second..."
    sleep 1
    STATUS_MS=$(helm ls metrics-server | grep metrics-server | awk '{print $8}')
  done
  echo "Metrics Server deployed successfully"

  STATUS_K8S_DASHBOARD=$(helm ls kubernetes-dashboard | grep kubernetes-dashboard | awk '{print $8}')
  while [ "$STATUS_K8S_DASHBOARD" != "DEPLOYED" ]; do
    echo "Kubernets Dashboard is still deploying, sleeping for a second..."
    sleep 1
    STATUS_K8S_DASHBOARD=$(helm ls kubernetes-dashboard | grep kubernetes-dashboard | awk '{print $8}')
  done
  echo "Kubernets Dashboard deployed successfully"

  STATUS_WEAVESCOPE=$(helm ls weave-scope | grep weave-scope | awk '{print $8}')
  while [ "$STATUS_WEAVESCOPE" != "DEPLOYED" ]; do
    echo "WeaveScope is still deploying, sleeping for a second..."
    sleep 1
    STATUS_K8S_DASHBOARD=$(helm ls weave-scope | grep weave-scope | awk '{print $8}')
  done
  echo "WeaveScope deployed successfully"


  # Below logic is for AWS Systems Manager return code for the script
  STATUS_WEAVESCOPE=$(helm ls weave-scope | grep weave-scope | awk '{print $8}')
  if [ "$STATUS_WEAVESCOPE" = "DEPLOYED" ]; then
    exit 0
  else
    exit 1
  fi
fi
