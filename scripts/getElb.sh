#!/bin/bash
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
  ELBADDRESS=$(kubectl get services $INGRESS_RELEASE-nginx-ingress-controller --namespace=$DESIREDNAMESPACE -o jsonpath={.status.loadBalancer.ingress[0].hostname})
  echo $ELBADDRESS
fi