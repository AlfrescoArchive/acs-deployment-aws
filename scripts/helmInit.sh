#!/bin/bash

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

export PATH=$PATH:/usr/local/bin
export HOME=/root
export KUBECONFIG=/home/ec2-user/.kube/config

WAIT_INTERVAL=1
COUNTER=0
TIMEOUT=300
t0=`date +%s`

echo "Waiting for nodes to be ready"
# We need to wait for the minimum 2 expected worker nodes to be available before deploying tiller pod
until [ $(kubectl get nodes | grep Ready -c) -ge 2 ] || [ "$COUNTER" -eq "$TIMEOUT" ]; do
   printf '.'
   sleep $WAIT_INTERVAL
   COUNTER=$(($COUNTER+$WAIT_INTERVAL))
done

if (("$COUNTER" < "$TIMEOUT")) ; then
   t1=`date +%s`
   delta=$((($t1 - $t0)/60))
   echo "Minimum 2 worker nodes are now ready in $delta minutes"
else
   echo "Waited $COUNTER seconds"
   echo "Not all nodes are ready."
   exit 1
fi

# We get Bastion AZ and Region to get a valid right region and query for volumes
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
BASTION_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${BASTION_AZ%?}
# We use this tag below to find the proper EKS cluster name and figure out the unique volume
TAG_NAME="KubernetesCluster"
TAG_VALUE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$TAG_NAME" --region $REGION --output=text | cut -f5)
# EKSname is not unique if we have multiple ACS deployments in the same cluster
# it must be somethign unique per Alfresco deployment, not per EKS cluster.
SOLR_VOLUME1_NAME_TAG="$TAG_VALUE-SolrVolume1"
SOLR_VOLUME1_AZ_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Name,Values=$SOLR_VOLUME1_NAME_TAG" --query "Volumes[?State=='available'].{Volume:VolumeId,AvailabilityZone:AvailabilityZone}" --output text)
SOLR_VOLUME1_AZ=$(echo $SOLR_VOLUME1_AZ_ID|awk '{ print $1 }')
SOLR_VOLUME1_ID=$(echo $SOLR_VOLUME1_AZ_ID|awk '{ print $2 }')
SOLRNODE=$(kubectl get nodes --selector failure-domain.beta.kubernetes.io/zone=$SOLR_VOLUME1_AZ | grep -v ^NAME | awk '{print $1}')

kubectl taint nodes $SOLRNODE SolrMasterOnly=true:NoSchedule
kubectl label nodes $SOLRNODE SolrMasterOnly=true

TILLER=$(kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase})
if [ "$TILLER" != "Running" ]; then
  echo Tiller is not running.  Creating one...
  helm init --service-account tiller
  TILLER=$(kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase})
  while [ "$TILLER" != "Running" ]; do
    echo tiller pod is still creating, sleeping for a second...
    sleep 1
    TILLER=$(kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase})
  done
fi
echo Tiller created successfully
helm repo add alfresco-incubator http://kubernetes-charts.alfresco.com/incubator
helm repo add alfresco-stable http://kubernetes-charts.alfresco.com/stable
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
# Below logic is for AWS Systems Manager return code of the script
TILLER=$(kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase})

if [ "$TILLER" = "Running" ]; then
  exit 0
else
  exit 1
fi
