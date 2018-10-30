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
      echo "apiVersion: v1
      kind: Secret
      metadata:
        name: quay-registry-secret
        namespace: $DESIREDNAMESPACE
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: $REGISTRYCREDENTIALS" >> secret.yaml
      kubectl create -f secret.yaml
    else
      echo "REGISTRYCREDENTIALS provided is not base64 encoded skipping..."
      # Terminate the stack as it would fail anyways.
      exit 1
    fi
  else
    echo "REGISTRYCREDENTIALS value is empty skipping..."
  fi

  ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')
  
  if [ "$INSTALL" = "true" ]; then
    echo Installing Alfresco Content Services helm chart...
    helm install alfresco-incubator/alfresco-content-services --version 1.1.4 \
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
      --set repository.environment.JAVA_OPTS=" -Dopencmis.server.override=true -Dopencmis.server.value=https://$EXTERNAL_NAME -Dalfresco.restApi.basicAuthScheme=true -Dsolr.base.url=/solr -Dsolr.secureComms=none -Dindex.subsystem.name=solr6 -Dalfresco.cluster.enabled=true -Ddeployment.method=HELM_CHART -Xms2000M -Xmx2000M" \
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
      --set repository.image.repository="alfresco/alfresco-content-repository-aws" \
      --set repository.image.tag="6.1.0-EA3" \
      --set registryPullSecrets=quay-registry-secret \
      --set repository.replicaCount=2 \
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