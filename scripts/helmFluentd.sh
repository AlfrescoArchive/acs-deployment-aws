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
  echo -e "--stackname \t CFN stack name"
  echo -e "--namespace \t Namespace to install"
  echo -e "--instance-role \t workernode IAM role"
  echo -e "--region \t region where is deployed"
  echo -e "--loggroup \t loggroup where logs are sent"
  echo -e "--install \t Install a new ACS Helm chart"
}

if [ $# -lt 6 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --stackname)
              STACKNAME="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
              shift 2
              ;;
          --instance-role)
              INSTANCE_ROLE="$2";
              shift 2
              ;;
          --region)
              REGION="$2";
              shift 2
              ;;
          --loggroup)
              LOG_GROUP="$2";
              shift 2
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
    echo Installing Fluentd CloudWatchLogs helm chart...
    # init not needed since it is initilized on helmInit.sh
    # helm init --client-only
    # helm repo update

    # This option below is because the container runs as user fluentd
    # to be able to write pos files to the workernode system, requires to run fluentd as root
    # https://github.com/helm/charts/tree/master/incubator/fluentd-cloudwatch
    cat <<EOF >> /tmp/extraVars.yaml
      extraVars:
        - "{ name: FLUENT_UID, value: '0' }"
EOF

    helm install incubator/fluentd-cloudwatch \
      --name $STACKNAME-fluentd-cloudwatch \
      --namespace=$DESIREDNAMESPACE \
      --set awsRole=$INSTANCE_ROLE \
      --set awsRegion=$REGION \
      --set rbac.create=true \
      --set logGroupName=$LOG_GROUP \
      -f /tmp/extraVars.yaml
  fi

  STATUS=$(helm ls $STACKNAME-fluentd-cloudwatch | grep fluentd-cloudwatch | awk '{print $8}')
  while [ "$STATUS" != "DEPLOYED" ]; do
    echo fluentd cloudwatch is still deploying, sleeping for a second...
    sleep 1
    STATUS=$(helm ls $STACKNAME-fluentd-cloudwatch | grep fluentd-cloudwatch | awk '{print $8}')
  done
  echo fluentd cloudwatch deployed successfully
  # Below logic is for AWS Systems Manager return code for the script
  STATUS=$(helm ls $STACKNAME-fluentd-cloudwatch | grep fluentd-cloudwatch | awk '{print $8}')
  if [ "$STATUS" = "DEPLOYED" ]; then
    exit 0
  else
    exit 1
  fi
fi
