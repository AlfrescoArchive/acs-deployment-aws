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
  echo -e "--acs-release \t Alfresco Content Services release name"
  echo -e "--efs-name \t Elastic File System name"
  echo -e "--namespace \t Namespace to install nginx-ingress"
  echo -e "--alfresco-password \t Alfresco admin password"
  echo -e "--rds-endpoint \t RDS Endpoint for Aurora MySql connection"
  echo -e "--database-password \t Database password"
  echo -e "--external-name \t External host name of ACS"
  echo -e "--registry-secret \t Base64 dockerconfig.json string to private registry"
  echo -e "--install \t Install a new ACS Helm chart"
  echo -e "--upgrade \t Upgrade an existing ACS Helm Chart"
}

if [ $# -lt 11 ]; then
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
          --efs-name)
              EFS_NAME="$2";
              shift 2
              ;;
          --s3bucket-name)
              S3BUCKET_NAME="$2";
              shift 2
              ;;
          --s3bucket-kms-alias)
              S3BUCKET_KMS_ALIAS="$2";
              shift 2
              ;;
          --s3bucket-location)
              S3BUCKET_LOCATION="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
              shift 2
              ;;
          --alfresco-password)
              ALFRESCO_PASSWORD="$2";
              shift 2
              ;;
          --rds-endpoint)
              RDS_ENDPOINT="$2";
              shift 2
              ;;
          --database-password)
              DATABASE_PASSWORD="$2";
              shift 2
              ;;
          --external-name)
              EXTERNAL_NAME="$2";
              shift 2
              ;;
          --registry-secret)
              REGISTRYCREDENTIALS="$2";
              shift 2
              ;;
          --install)
              INSTALL="true";
              shift
              ;;
          --upgrade)
              UPGRADE="true";
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

  cmd="import re; string='${REGISTRYCREDENTIALS}'; print True if len(string) % 4 == 0 and re.match('^[A-Za-z0-9+\/=]+\Z', string) else False"
  isBase64(){
    checkVar=$(python -c "${cmd}" )
    echo $checkVar
  }

  if [ ! -z ${REGISTRYCREDENTIALS} ]; then
    if [[ $(isBase64) == "True" ]]; then
      echo "Creating secrets file to access private repository"
      cat <<EOF > secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
  namespace: $DESIREDNAMESPACE
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $REGISTRYCREDENTIALS
EOF
      kubectl create -f secret.yaml
    else
      echo "REGISTRYCREDENTIALS provided is not base64 encoded skipping..."
      # Terminate the stack as it would fail anyways.
      exit 1
    fi
  else
    echo "REGISTRYCREDENTIALS value is empty skipping..."
  fi

  WAIT_INTERVAL=1
  COUNTER=0
  TIMEOUT=300
  t0=`date +%s`

  echo "Waiting for nodes to be ready"
  until [ $(kubectl get nodes | grep Ready -c) -eq 2 ] || [ "$COUNTER" -eq "$TIMEOUT" ]; do
     printf '.'
     sleep $WAIT_INTERVAL
     COUNTER=$(($COUNTER+$WAIT_INTERVAL))
  done

  if (("$COUNTER" < "$TIMEOUT")) ; then
     t1=`date +%s`
     delta=$((($t1 - $t0)/60))
     echo "All 2 nodes ready in $delta minutes"
  else
     echo "Waited $COUNTER seconds"
     echo "Not all nodes are ready."
     exit 1
  fi

  MASTERNODE=$(kubectl get nodes | awk '{print $1}' | awk 'FNR == 3 {print}')

  kubectl taint nodes $MASTERNODE SolrMasterOnly=true:NoSchedule
  kubectl label nodes $MASTERNODE SolrMasterOnly=true

  # variable region has to be figured out with:
  AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
  REGION=${AZ::-1}
  # Find the volume created from CFN
  SOLR_EBS_VOLUME=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Component,Values=SolrVolume1" --query "Volumes[?State=='available'].{Created:CreateTime,Volume:VolumeId}" --output text|tail -1|awk '{ print $2 }')

  ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')

  if [ "$INSTALL" = "true" ]; then
    echo Installing Alfresco Content Services helm chart...

echo "externalProtocol: https
externalHost: \"$EXTERNAL_NAME\"
externalPort: \"443\"
repository:
  adminPassword: \"$ALFRESCO_PASSWORD\"
  image:
    repository: \"alfresco/alfresco-content-repository-aws\"
    tag: \"0.1.3-repo-6.0.0.3\"
  replicaCount: 1
  environment:
    JAVA_OPTS: \" -Dopencmis.server.override=true -Dopencmis.server.value=https://$EXTERNAL_NAME -Dalfresco.restApi.basicAuthScheme=true -Dsolr.base.url=/solr -Dsolr.secureComms=none -Dindex.subsystem.name=solr6 -Dalfresco.cluster.enabled=true -Ddeployment.method=HELM_CHART -Xms2000M -Xmx2000M\"
alfresco-search:
  resources:
    requests:
      memory: \"2500Mi\"
    limits:
      memory: \"2500Mi\"
  environment:
    SOLR_JAVA_MEM: \"-Xms2000M -Xmx2000M\"
  persistence:
   EbsPvConfiguration:
     volumeID: \"$SOLR_EBS_VOLUME\"
  affinity: |
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            - key: \"SolrMasterOnly\"
              operator: In
              values:
              - \"true\"
  tolerations:
  - key: \"SolrMasterOnly\"
    operator: \"Equal\"
    value: \"true\"
    effect: \"NoSchedule\"
  PvNodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: \"SolrMasterOnly\"
          operator: In
          values:
          - \"true\"
persistence:
  solr:
    data:
      subPath: \"$DESIREDNAMESPACE/alfresco-content-services/solr-data\"
  repository:
    enabled: false
postgresql:
  enabled: false
database:
  external: true
  driver: \"org.mariadb.jdbc.Driver\"
  url: \"'jdbc:mariadb:aurora//$RDS_ENDPOINT:3306/alfresco?useUnicode=yes&characterEncoding=UTF-8'\"
  user: \"alfresco\"
  password: \"$DATABASE_PASSWORD\"
s3connector:
  enabled: true
  config:
    bucketName: \"$S3BUCKET_NAME\"
    bucketLocation: \"$S3BUCKET_LOCATION\"
  secrets:
    encryption: kms
    awsKmsKeyId: \"$S3BUCKET_KMS_ALIAS\"
registryPullSecrets: quay-registry-secret" >> values.yaml

    helm install alfresco-incubator/alfresco-content-services --version 1.1.5-SEARCH-1227 --name $ACS_RELEASE -f values.yaml --namespace=$DESIREDNAMESPACE

  fi

  if [ "$UPGRADE" = "true" ]; then
    echo Upgrading Alfresco Content Services helm chart...
    helm upgrade $ACS_RELEASE alfresco-incubator/alfresco-content-services \
      --install \
      --set externalProtocol="https" \
      --set externalHost="$EXTERNAL_NAME" \
      --set externalPort="443" \
      --set repository.adminPassword="$ALFRESCO_PASSWORD" \
      --set alfresco-infrastructure.persistence.efs.enabled=true \
      --set alfresco-infrastructure.persistence.efs.dns="$EFS_NAME" \
      --set alfresco-search.resources.requests.memory="2500Mi",alfresco-search.resources.limits.memory="2500Mi" \
      --set alfresco-search.environment.SOLR_JAVA_MEM="-Xms2000M -Xmx2000M" \
      --set database.password="$DATABASE_PASSWORD" \
      --namespace=$DESIREDNAMESPACE
  fi

  STATUS=$(helm ls $ACS_RELEASE | grep $ACS_RELEASE | awk '{print $8}')
  while [ "$STATUS" != "DEPLOYED" ]; do
    echo alfresco content services is still deploying, sleeping for a second...
    sleep 1
    STATUS=$(helm ls $ACS_RELEASE | grep $ACS_RELEASE | awk '{print $8}')
  done
  echo alfresco content services deployed successfully
  # Below logic is for AWS Systems Manager return code for the script
  STATUS=$(helm ls $ACS_RELEASE | grep $ACS_RELEASE | awk '{print $8}')
  if [ "$STATUS" = "DEPLOYED" ]; then
    exit 0
  else
    exit 1
  fi
fi