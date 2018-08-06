# Alfresco Content Services Deployment on AWS Cloud

## Overview

This project contains the code for the AWS based Alfresco Content Services (Enterprise) product on AWS Cloud using Cloudformation template.  It is build with a main cloudformation template that will also spin sub-stacks for VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with EKS Master) in an auto-scaling group.

## Prerequisites

To run the Alfresco Content Services (ACS) deployment on AWS in a Kops provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| Kubectl     | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| AWS Cli     | https://github.com/aws/aws-cli#installation |
**Note:** You need to clone this repository to deploy Alfresco Content Services.

## Limitations

This setup will work as of now only in AWS US East (N.Virginia) and West (Oregon) regions due to current EKS support.

### How to deploy ACS Cluster on AWS using CLI

* Clone the repository:
```bash
git clone git@git.alfresco.com:Repository/acs-deployment-aws.git
cd acs-deployment-aws
```

* Export the AWS user credentials:
```bash
# Access Key & Secret
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
export AWS_DEFAULT_REGION="<region-name>"
(or)
# AWS Profile
export AWS_PROFILE="<profile-name>"
```

* Create an s3 bucket to store sub-stack cloudformation templates
```bash
$ aws s3 mb s3://my-bucket-name
``` 

* Copy templates in the bucket
```bash
aws s3 cp templates/bastion-and-eks-cluster.yaml s3://my-bucket-name/acs-submodules/
aws s3 cp templates/efs.yaml s3://my-bucket-name/acs-submodules/
```

* Validate master acs-deployment template before creating the cluster
```bash
aws cloudformation validate-template --template-body file://templates/acs-deployment-master.yaml
```
**Note**: This should not complain of any errors, if so then do not proceed and debug errors.

* Create acs-deployment stack
```bash
aws cloudformation create-stack \
  --stack-name my-acs-stack \
  --template-body file://templates/acs-deployment-master.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=<MyKey.pem> \
               ParameterKey=AvailabilityZones,ParameterValue=us-east-1a\\,us-east-1b \
               ParameterKey=RemoteAccessCIDR,ParameterValue=<C.I.D.R/32> \
               ParameterKey=TemplateBucketName,ParameterValue=my-bucket-name \
               ParameterKey=TemplateBucketKeyPrefix,ParameterValue=acs-submodules             
```

This should take some time to complete the ACS Deployment.  You can see the status of stacks in AWS Console.  Once the stack if successfully completed, several stack Outputs and available.

More technical documentation is available inside [docs](docs/).