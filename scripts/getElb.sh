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
  echo -e "--ingress-release \t nginx-ingress release name"
  echo -e "--namespace \t Namespace to install nginx-ingress"
}

if [ $# -lt 2 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --ingress-release)
              INGRESS_RELEASE="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
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

  CONTROLLER=$(kubectl get pods -l app=nginx-ingress,component=controller --namespace $DESIREDNAMESPACE -o jsonpath={.items..phase})
  while [ "$CONTROLLER" != "Running" ]; do
    sleep 1
    CONTROLLER=$(kubectl get pods -l app=nginx-ingress,component=controller --namespace $DESIREDNAMESPACE -o jsonpath={.items..phase})
  done

  # Double check the ELBADDRESS is not empty to eliminate race situation.
  ELBADDRESS=$(kubectl get services $INGRESS_RELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
  if [ -z "$ELBADDRESS" ]; then
    ELBADDRESS=$(kubectl get services $INGRESS_RELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
    while [ -z "$ELBADDRESS" ]; do
      sleep 1
      ELBADDRESS=$(kubectl get services $INGRESS_RELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
    done
  fi
  
  # Triple check it's an ELB address
  ELBADDRESS=$(kubectl get services $INGRESS_RELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
  if [[ "$ELBADDRESS" =~ ".elb.amazonaws.com" ]]; then
    echo $ELBADDRESS
  else
    echo "Something is wrong with the nginx-ingress.  Exiting..."
    exit 1
  fi
fi