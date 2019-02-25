#!/bin/bash

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
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
  echo -e "--releasename \t helm release name"
  echo -e "--region \t region where is deployed"
  echo -e "--clustername \t EKS cluster name"
}

if [ $# -lt 3 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --releasename)
              RELEASE_NAME="$2";
              shift 2
              ;;
          --region)
              REGION="$2";
              shift 2
              ;;
          --clustername)
              CLUSTER_NAME="$2";
              shift 2
              ;;
          --)
              break
              ;;
          *)
              break
              ;;
      esac
  done

  # NOTE: The cluster autoscaler version number is dependant on the K8S version it is being 
  #       deployed into. See...
  #       https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler#releases

  helm install stable/cluster-autoscaler \
    --name $RELEASE_NAME \
    --namespace kube-system \
    --set image.tag=v1.3.5 \
    --set autoDiscovery.clusterName=$CLUSTER_NAME \
    --set extraArgs.balance-similar-node-groups=false \
    --set extraArgs.expander=random \
    --set rbac.create=true \
    --set rbac.pspEnabled=true \
    --set awsRegion=$REGION \
    --set sslCertPath=/etc/ssl/certs/ca-bundle.crt \
    --set cloudProvider=aws \

  STATUS=$(helm ls $RELEASE_NAME | grep autoscaler | awk '{print $8}')
  while [ "$STATUS" != "DEPLOYED" ]; do
    echo cluster autoscaler is still deploying, sleeping for a second...
    sleep 1
    STATUS=$(helm ls $RELEASE_NAME | grep autoscaler | awk '{print $8}')
  done
  echo cluster autoscaler deployed successfully
  exit 0
fi
