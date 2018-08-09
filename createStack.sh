#!/bin/bash

# Util
separator() {
    echo "============================"
}

logInfo() {
    echo "info::: $1"
}

logError() {
    echo "error::: $1"
    exit 1
}

printVarSummary() {
    separator
    echo "Variables Summary"
    separator
    for var in $VAR_LIST
    do
        echo "$var = ${!var}"
    done
    separator
}

usage() {
  echo "Usage: aws_quickstart_createStack.sh <access_key_id> <secret_access_key> <cfn_template_body> <parameters_file> <stack_name> <aws_region>"
  exit 1
}

if [ $# -lt 6 ]; then
  usage
else
  export AWS_ACCESS_KEY_ID=$1
  export AWS_SECRET_ACCESS_KEY=$2
  TEMPLATE_BODY="$3"
  PARAMETERS_FILE="$4"
  STACK_NAME=$(echo -n $5 | tr / - | awk '{print tolower($0)}')
  AWS_REGIOM=$6

  CAPABILITIES=CAPABILITY_IAM
  STACK_CREATION_TIMEOUT=600

  # Some logging
  printVarSummary

  # Validate the template
  separator
  logInfo "Validate the Cloudformation template"
  aws cloudformation validate-template --template-body file://$TEMPLATE_BODY --region $6

  # Create the stack
  separator
  aws cloudformation create-stack \
      --stack-name $STACK_NAME \
      --template-body file://$TEMPLATE_BODY \
      --parameters file://$PARAMETERS_FILE \
      --region $6 \
      --capabilities $CAPABILITIES
      # --disable-rollback

  if [ $? -ne 0 ]; then
    logError "Stack creation failed."
  fi

  # Wait until stack complete
  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

  # Show stack
  aws cloudformation describe-stacks --stack-name $STACK_NAME
fi