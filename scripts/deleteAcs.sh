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
  echo -e "--acs-release \t ACS release name"
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
          --acs-release)
              ACS_RELEASE="$2";
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

  helm delete --purge $ACS_RELEASE
  echo ACS deleted successfully
fi