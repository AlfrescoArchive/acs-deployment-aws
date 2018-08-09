#!/bin/bash

if [[ $# -ne 2 ]] ; then
    echo 'wrong number of parameters usage: ./createStack.sh <stack-name> <s3-bucket>'
    exit 1
fi

STACK_NAME=$1
S3_BUCKET=$2

aws s3 cp ./templates s3://$S3_BUCKET/acs --recursive
aws s3 cp ./lambdas s3://$S3_BUCKET/acs/lambdas --recursive

aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://templates/acs-deployment-master.yaml --capabilities CAPABILITY_IAM --parameters file://templates/acs-master-parameters.json --disable-rollback

