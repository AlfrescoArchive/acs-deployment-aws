#!/bin/bash
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

if [ $# -lt 12 ]; then
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

echo "apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
  namespace: $DESIREDNAMESPACE
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $REGISTRYCREDENTIALS" >> secret.yaml
kubectl create -f secret.yaml

  ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')

  if [ "$INSTALL" = "true" ]; then
    echo Installing Alfresco Content Services helm chart...
    helm install alfresco-incubator/alfresco-content-services \
      --name $ACS_RELEASE \
      --set externalProtocol="https" \
      --set externalHost="$EXTERNAL_NAME" \
      --set externalPort="443" \
      --set repository.adminPassword="$ALFRESCO_PASSWORD" \
      --set alfresco-infrastructure.persistence.efs.enabled=true \
      --set alfresco-infrastructure.persistence.efs.dns="$EFS_NAME" \
      --set alfresco-search.resources.requests.memory="2500Mi",alfresco-search.resources.limits.memory="2500Mi" \
      --set alfresco-search.environment.SOLR_JAVA_MEM="-Xms2000M -Xmx2000M" \
      --set persistence.solr.data.subPath="$DESIREDNAMESPACE/alfresco-content-services/solr-data" \
      --set postgresql.enabled=false \
      --set database.external=true \
      --set database.driver="org.mariadb.jdbc.Driver" \
      --set database.url="'jdbc:mariadb:aurora//$RDS_ENDPOINT:3306/alfresco?useUnicode=yes&characterEncoding=UTF-8'" \
      --set database.user="alfresco" \
      --set database.password="$DATABASE_PASSWORD" \
      --set persistence.repository.enabled=false \
      --set s3connector.enabled=true \
      --set s3connector.config.bucketName="$S3BUCKET_NAME" \
      --set s3connector.config.bucketLocation="$S3BUCKET_LOCATION" \
      --set s3connector.secrets.encryption=kms \
      --set s3connector.secrets.awsKmsKeyId="$S3BUCKET_KMS_ALIAS" \
      --set repository.image.repository="quay.io/alfresco/alfresco-content-repository-aws" \
      --set repository.image.tag="0.1.1-repo-6.0.0" \
      --set registryPullSecrets=quay-registry-secret \
      --namespace=$DESIREDNAMESPACE
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