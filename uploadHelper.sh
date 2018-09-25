#!/bin/bash

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

if [ $# -ne 2 ]; then
  echo "Usage: uploadHelper.sh <TemplateBucketName> <TemplateBucketKeyPrefix>"
  exit 1
else
  S3_BUCKET=$1
  S3_KEY_PREFIX=$2

  # Check if access to the bucket
  if aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q 'An error occurred'
  then
    echo "No access to S3 bucket: $S3_BUCKET !"
    exit 1
  fi

  aws s3 cp ./templates s3://$S3_BUCKET/$S3_KEY_PREFIX/templates --recursive
  aws s3 cp ./scripts s3://$S3_BUCKET/$S3_KEY_PREFIX/scripts --recursive
  aws s3 cp ./lambdas/eks-helper-lambda/eks-helper-lambda.zip s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/
  aws s3 cp ./lambdas/helm-helper-lambda/helm-helper-lambda.zip s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/
  aws s3 cp ./lambdas/empty-s3-bucket/alfresco-lambda-empty-s3-bucket.jar s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/
fi