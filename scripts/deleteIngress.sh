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
          --ingress-release)
              INGRESS_RELEASE="$2";
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

  helm delete --purge $INGRESS_RELEASE
  echo nginx-ingress deleted successfully
fi