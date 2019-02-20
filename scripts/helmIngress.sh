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
  echo -e "--ingress-version \t nginx-ingress release version"
  echo -e "--namespace \t Namespace to install nginx-ingress"
  echo -e "--aws-cert-arn \t AWS SSL Certificate Arn"
  echo -e "--aws-cert-policy \t AWS SSL Certificate Policy"
  echo -e "--external-name \t External host name of ACS"
  echo -e "--elb-tags \t Set of tags to add to the ELB"
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
          --ingress-release)
              INGRESS_RELEASE="$2";
              shift 2
              ;;
          --ingress-version)
              INGRESS_VERSION="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
              shift 2
              ;;
          --aws-cert-arn)
              AWS_CERT_ARN="$2";
              shift 2
              ;;
          --aws-cert-policy)
              AWS_CERT_POLICY="$2";
              shift 2
              ;;
          --external-name)
              EXTERNAL_NAME="$2";
              shift 2
              ;;
          --elb-tags)
              ELB_TAGS="$2";
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

  # Double check tiller is running before going ahead
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

  echo Installing nginx-ingress helm chart...
cat <<EOF > ingressvalues.yaml
rbac:
  create: true
controller:
  config:
    force-ssl-redirect: "true"
  scope:
    enabled: true
    namespace: $DESIREDNAMESPACE
  publishService:
    enabled: true
  service:
    targetPorts:
      https: 80
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "$AWS_CERT_ARN"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      external-dns.alpha.kubernetes.io/hostname: "$EXTERNAL_NAME"
      service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "$AWS_CERT_POLICY"
      service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "$ELB_TAGS"
EOF

  helm upgrade $INGRESS_RELEASE stable/nginx-ingress -f ingressvalues.yaml --install --version $INGRESS_VERSION --namespace $DESIREDNAMESPACE

  STATUS=$(helm ls $INGRESS_RELEASE | grep $INGRESS_RELEASE | awk '{print $8}')
  while [ "$STATUS" != "DEPLOYED" ]; do
    echo nginx-ingress is still creating, sleeping for a second...
    sleep 1
    STATUS=$(helm ls $INGRESS_RELEASE | grep $INGRESS_RELEASE | awk '{print $8}')
  done
  echo nginx-ingress created successfully
  # Below logic is for AWS Systems Manager return code for the script
  STATUS=$(helm ls $INGRESS_RELEASE | grep $INGRESS_RELEASE | awk '{print $8}')
  if [ "$STATUS" = "DEPLOYED" ]; then
    exit 0
  else
    exit 1
  fi
fi