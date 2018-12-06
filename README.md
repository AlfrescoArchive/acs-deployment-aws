# Alfresco Content Services Deployment on AWS Cloud

## Overview

This project contains the code for the AWS-based Alfresco Content Services (Enterprise) product on AWS Cloud using an AWS CloudFormation template.  It's built with a main CloudFormation (CFN) template that also spins up sub-stacks for a VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with the EKS Master) in an auto-scaling group.

**Note:** You need to clone this repository to deploy Alfresco Content Services.

## Limitations

Currently, this setup will only work in AWS US East (N.Virginia) and West (Oregon) regions.

## How to deploy ACS Cluster on AWS
### Prerequisites
* You need a hosted zone e.g. example.com. See [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
* An SSL certificate for the Elastic Load Balancer and the domains in the hosted zone [Creating SSL Cert](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html)
* For some of the images from the Helm installation access to [Alfresco's repository in quay.io](https://quay.io/repository/alfresco) is required.

### Permissions
Ensure that the IAM role or IAM user that creates the stack allows the following permissions:

```
ec2:AssociateAddress
ec2:DescribeAddresses

eks:CreateCluster
eks:Describe

iam:PassRole

kms:Decrypt
kms:Encrypt

logs:CreateLogStream
logs:GetLogEvents
logs:PutLogEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:PutRetentionPolicy
logs:PutMetricFilter
logs:CreateLogGroup

s3:GetObject
s3:GetReplicationConfiguration
s3:ListBucket
s3:GetObjectVersionForReplication
s3:GetObjectVersionAcl
s3:PutObject
s3:ReplicateObject

sts:AssumeRole
```

### Preparing the S3 bucket for CFN template deployment
The master template (`templates/acs-deployment-master.yaml`) requires a few supporting files hosted in S3, like lambdas, scripts and CFN templates. To do this, create or use an S3 bucket in the same region as you intend to deploy ACS. Also, the S3 bucket needs to have a key prefix in it:
```s3://<bucket_name>/<key_prefix>``` (e.g. ```s3://my-s3-bucket/development```)

**Note:** With S3 in AWS Console you can create the `<key_prefix>` when creating a folder.

To simplify the upload, we created a helper script named **uploadHelper.sh**, which only works with Mac or Linux. For Windows, upload those files manually. Initiate the upload by following the instructions below:
1) Open a terminal and change directory to the cloned repository.
2) ```chmod +x uploadHelper.sh```
3) ```./uploadHelper.sh <bucket_name> <key_prefix>```. This will upload the files to S3.
4) Check that the bucket contains the following files:

```
s3://<bucket_name> e.g. my-s3-bucket
          |-- <key_prefix> e.g. development
          |       |-- lambdas
          |       |      |-- eks-helper-lambda.zip
          |       |      +-- alfresco-lambda-empty-s3-bucket.jar
          |       |      +-- helm-helper-lambda.zip
          |       |-- scripts
          |       |      |-- deleteIngress.sh
          |       |      +-- getElb.sh
          |       |      +-- helmAcs.sh
          |       |      +-- helmIngress.sh
          |       |      +-- helmInit.sh
          |       |-- templates
          |       |      |-- acs.yaml
          |       |      +-- acs-deployment-master.yaml
          |       |      +-- acs-master-parameters.json
          |       |      +-- bastion-and-eks-cluster.yaml
          |       |      +-- efs.yaml
          |       |      +-- rds.yaml
          |       |      +-- s3-bucket.yaml
```

## Deploying ACS EKS with AWS Console
**Note:** To use the AWS Console, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

* Go to the AWS Console and open CloudFormation
* Click ```Create Stack```
* In ```Upload a template to Amazon S3``` choose `templates/acs-deployment-master.yaml`
* Choose a stack name, like `my-acs-eks`
* Fill out the parameters. In many cases you can use the default parameters. For some parameter sections
we will provide some additional information.

**S3 Cross Replication Bucket for storing ACS content store**

```Enable Cross Region Replication for This Bucket``` : Cross Region Replication replicates your data into another bucket. This is optional. See [Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/dev/crr.html) for more information.

**ACS Stack Configuration**

```The name of the S3 bucket that holds the templates``` : Take the bucket name from the upload step.

```The Key prefix for the templates in the S3 template bucket``` : Take the `key_prefix` from the upload step.

```The ACS SSL Certificate arn to use with ELB``` : Take the SSL certificate arn for your domains in the hosted zone, e.g. `arn:aws:acm:us-east-1:1234567890:certificate/a08b75c0-311d-4999-9995-39fefgh519i9`. For more information about how to create SSL certificates, see the AWS documentation on the [AWS Certificate Manager](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html).

```The ACS domain name``` : Choose the subdomain which will be used for the url e.g. **my-acs-eks.example.com**. For more information about how to create a hosted zone and its subdomains visit the AWS documentation on [Creating a Subdomain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html).

```Route53 Dns Zone``` : Choose the Route53 DNS Zone which will be used to create  e.g. **example.com.** (note the dot at the end). For more information about how to create a hosted zone and its subdomains visit the AWS documentation on [Creating a Subdomain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html).

```Private Registry Credentials. Base64 encryption of dockerconfig json``` : \
**Notice:** Make sure you have access to [Alfresco's repository in quay.io](https://quay.io/repository/alfresco).
1) Login to quay.io with ```docker login quay.io```.
2) Validate that you can see the credentials with ```cat ~/.docker/config.json``` for quay.io.
3) Get the encoded credentials with ```cat ~/.docker/config.json | base64```.
4) Copy them into the textbox.

```The hosted zone to create Route53 Record for ACS``` : Enter your hosted zone e.g. **example.com.**. For more information about how to create a hosted zone, see the AWS documentation on [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html).

After the CFN stack creation has finished, you can find the Alfresco URL in the output from the master template.

### Deleting ACS EKS with AWS Console
Go to CloudFormation and delete the master ACS EKS stack. The nested stacks will be deleted first, followed by the master stack.


## Deploying ACS EKS with AWS Cli
**Note:** To use the Cli, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

### Prerequisites

To run the Alfresco Content Services (ACS) deployment on AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| AWS Cli     | https://github.com/aws/aws-cli#installation |


Create ACS EKS by using the [cloudformation command](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html). Make sure that you use the same bucket name and key prefix in the Cli command as you provided in [Prepare the S3 bucket for CFN template deployment](#prepare-the-s3-bucket-for-cfn-template-deployment).

```bash
aws cloudformation create-stack \
  --stack-name my-acs-eks \
  --template-body file://templates/acs-deployment-master.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=KeyPairName,ParameterValue=<MyKey.pem> \
               ParameterKey=AvailabilityZones,ParameterValue=us-east-1a\\,us-east-1b \
               ParameterKey=RemoteAccessCIDR,ParameterValue=<my_ip/32> \
               ParameterKey=TemplateBucketName,ParameterValue=<bucket_name> \
               ParameterKey=TemplateBucketKeyPrefix,ParameterValue=<key_prefix> \
               ParameterKey=EksExternalUserArn,ParameterValue=arn:aws:iam::<AccountId>:user/<IamUser> \
               ParameterKey=AcsExternalName,ParameterValue=<dns-name> \
               ParameterKey=RDSPassword,ParameterValue=<rds-password> \
               ParameterKey=AlfrescoPassword,ParameterValue=<admin-password> \
               ParameterKey=Route53DnsZone,ParameterValue=<dnsZone> \
               ParameterKey=ElbCertArn,ParameterValue=arn:aws:acm:us-east-1:<AccountId>:certificate/<elbCertId> \
               ParameterKey=RegistryCredentials,ParameterValue=<docker-registry-credentials>
```

### Deleting ACS EKS with AWS Cli
Open a terminal and enter:
```
aws cloudformation delete-stack --stack-name <master-acs-eks-stack>
```

## Cluster bastion access
To access the cluster using the deployed bastion, follow the instructions in [How to connect ACS bastion host remotely](docs/bastion_access.md).

## Cluster remote access
### Prerequisites

To access the Alfresco Content Services (ACS) deployment on AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| Kubectl     | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| IAM User    | https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html |

Follow the detailed instructions in [EKS cluster remote access](docs/eks_cluster_remote_access.md).

# License information
* The ACS images downloaded directly from hub.docker.com, or Quay.io are for a limited trial of the Enterprise version of Alfresco Content Services that goes into read-only mode after 2 days. Request an extended 30-day trial at https://www.alfresco.com/platform/content-services-ecm/trial/docker.
* To extend the trial license period and apply it to your running system, follow the steps in [Uploading a new license](http://docs.alfresco.com/6.0/tasks/at-adminconsole-license.html).
* If you plan to use the AWS deployment in production, you need to get an Enterprise license in order to use the S3 Connector AMP.
