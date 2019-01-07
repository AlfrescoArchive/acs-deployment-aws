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
  echo -e "--mq-endpoint \t MQ Endpoint for AmazonMQ connection"
  echo -e "--mq-username \t Username for AmazonMQ connection"
  echo -e "--mq-password \t Password for AmazonMQ connection"
  echo -e "--external-name \t External host name of ACS"
  echo -e "--registry-secret \t Base64 dockerconfig.json string to private registry"
  echo -e "--install \t Install a new ACS Helm chart"
  echo -e "--upgrade \t Upgrade an existing ACS Helm Chart"
  echo -e "--repo-pods \t Repo Replica number"
}

if [ $# -lt 15 ]; then
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
          --mq-endpoint)
              MQ_ENDPOINT="$2";
              shift 2
              ;;
          --mq-username)
              MQ_USERNAME="$2";
              shift 2
              ;;
          --mq-password)
              MQ_PASSWORD="$2";
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
          --repo-pods)
              REPO_PODS="$2";
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

  # We get Bastion AZ and Region to get a valid right region and query for volumes
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  BASTION_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
  REGION=${BASTION_AZ%?}
  # We use this tag below to find the proper EKS cluster name and figure out the unique volume
  TAG_NAME="KubernetesCluster"
  TAG_VALUE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$TAG_NAME" --region $REGION --output=text | cut -f5)
  # EKSname is not unique if we have multiple ACS deployments in the same cluster
  # It must be a name unique per Alfresco deployment, not per EKS cluster.
  SOLR_VOLUME1_NAME_TAG="$TAG_VALUE-SolrVolume1"
  SOLR_VOLUME1_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Name,Values=$SOLR_VOLUME1_NAME_TAG" --query "Volumes[?State=='available'].{Volume:VolumeId}" --output text)

  ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')

  if [ "$INSTALL" = "true" ]; then
    echo Installing Alfresco Content Services helm chart...

echo "externalProtocol: https
externalHost: \"$EXTERNAL_NAME\"
externalPort: \"443\"
alfresco-infrastructure:
  activemq:
    enabled: false
  persistence: 
    efs:
      enabled: true
      dns: \"$EFS_NAME\"
repository:
  livenessProbe:
    initialDelaySeconds: 420
  adminPassword: \"$ALFRESCO_PASSWORD\"
  image:
    repository: \"alfresco/alfresco-content-repository-aws\"
    tag: \"6.1.0-EA3\"
  replicaCount: $REPO_PODS
  environment:
    JAVA_OPTS: \" -Dopencmis.server.override=true -Dopencmis.server.value=https://$EXTERNAL_NAME -Dalfresco.restApi.basicAuthScheme=true -Dsolr.base.url=/solr -Dsolr.secureComms=none -Dindex.subsystem.name=solr6 -Dalfresco.cluster.enabled=true -Ddeployment.method=HELM_CHART -Dmessaging.broker.url='failover:($MQ_ENDPOINT)?timeout=3000&jms.useCompression=true' -Dmessaging.broker.user=$MQ_USERNAME -Dmessaging.broker.password=$MQ_PASSWORD -Xms2000M -Xmx2000M\"
alfresco-search:
  resources:
    requests:
      memory: \"12500Mi\"
    limits:
      memory: \"12500Mi\"
  environment:
    SOLR_JAVA_MEM: \"-Xms12000M -Xmx12000M\"
  persistence:
    VolumeSizeRequest: \"100Gi\"
    EbsPvConfiguration:
      volumeID: \"$SOLR_VOLUME1_ID\"
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
pdfrenderer:
  livenessProbe:
    initialDelaySeconds: 300
libreoffice:
  livenessProbe:
    initialDelaySeconds: 300
imagemagick:
  livenessProbe:
    initialDelaySeconds: 300
share:
  livenessProbe:
    initialDelaySeconds: 420
registryPullSecrets: quay-registry-secret" > acs_install_values.yaml

    helm install alfresco-incubator/alfresco-content-services --version 1.1.6 -f acs_install_values.yaml --name $ACS_RELEASE --namespace=$DESIREDNAMESPACE

  fi

  if [ "$UPGRADE" = "true" ]; then
    echo Upgrading Alfresco Content Services helm chart...
    helm upgrade $ACS_RELEASE alfresco-incubator/alfresco-content-services \
      --install \
      --reuse-values \
      --set externalHost="$EXTERNAL_NAME" \
      --set repository.adminPassword="$ALFRESCO_PASSWORD" \
      --set alfresco-infrastructure.persistence.efs.dns="$EFS_NAME" \
      --set persistence.solr.data.subPath="$DESIREDNAMESPACE/alfresco-content-services/solr-data" \
      --set postgresql.enabled=false \
      --set database.external=true \
      --set database.url="'jdbc:mariadb:aurora//$RDS_ENDPOINT:3306/alfresco?useUnicode=yes&characterEncoding=UTF-8'" \
      --set database.password="$DATABASE_PASSWORD" \
      --set s3connector.config.bucketName="$S3BUCKET_NAME" \
      --set s3connector.config.bucketLocation="$S3BUCKET_LOCATION" \
      --set s3connector.secrets.encryption=kms \
      --set s3connector.secrets.awsKmsKeyId="$S3BUCKET_KMS_ALIAS" \
      --set repository.environment.JAVA_OPTS=" -Dopencmis.server.override=true -Dopencmis.server.value=https://$EXTERNAL_NAME -Dalfresco.restApi.basicAuthScheme=true -Dsolr.base.url=/solr -Dsolr.secureComms=none -Dindex.subsystem.name=solr6 -Dalfresco.cluster.enabled=true -Ddeployment.method=HELM_CHART -Dmessaging.broker.url='failover:($MQ_ENDPOINT)?timeout=3000&jms.useCompression=true' -Dmessaging.broker.user=$MQ_USERNAME -Dmessaging.broker.password=$MQ_PASSWORD -Xms2000M -Xmx2000M" \
      --set repository.image.tag="6.1.0-EA3" \
      --set repository.replicaCount="$REPO_PODS" \
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
