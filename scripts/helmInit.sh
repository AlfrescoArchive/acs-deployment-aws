#!/bin/bash
export PATH=$PATH:/usr/local/bin
export HOME=/root
export KUBECONFIG=/home/ec2-user/.kube/config
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
# Below logic is for AWS Systems Manager return code of the script
TILLER=$(kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase})
if [ "$TILLER" = "Running" ]; then
  exit 0
else
  exit 1
fi
