# Alfresco Content Services Deployment Template for Amazon Elastic Service for Kubernetes (EKS)

## Overview

This project contains the code for the AWS-based Alfresco Content Services (Enterprise) product on AWS Cloud using an AWS CloudFormation template.  It's built with a main CloudFormation (CFN) template that also spins up sub-stacks for a VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with the EKS Master) in an auto-scaling group.

**Note:** You need to clone this repository to deploy Alfresco Content Services.

## Limitations

Currently, this setup will only work in AWS US East (N.Virginia) and West (Oregon) regions.

## How to deploy ACS Cluster on AWS
### Prerequisites
* You need a hosted zone e.g. example.com. See the AWS documentation on [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html).
* An SSL certificate for the Elastic Load Balancer and the domains in the hosted zone. See the AWS documentation on [Creating SSL Certificates](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html).
* Private Docker images from Quay.io are used during the Helm deployment. You need access to a secret with credentials to be able to pull those images. Alfresco customers and partners can request their credentials by logging a ticket at https://support.alfresco.com.

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
The master template (`templates/acs-deployment-master.yaml`) requires a few supporting files hosted in S3, like lambdas, scripts and CFN templates.

Before you begin, make sure you:
* Create or use an S3 bucket in the same region as you intend to deploy ACS.
* Add a key prefix to the bucket name after you've created it:
`s3://<bucket_name>/<key_prefix>` (e.g. ```s3://my-s3-bucket/development``` )

To create the S3 bucket and key prefix:
* Go to the **AWS Console**, and open the **S3** console.
* Create an S3 bucket using the default settings.
* Select the bucket that you just created in the **Bucket name** list, and click **Create folder**.
* Type a name for the folder, choose the encryption setting, and then click **Save**.

**Note:** The `<key_prefix>` acts as a folder object in the S3 bucket, to allow objects to be grouped together. See the AWS documentation on [Using folders in an S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/using-folders.html) for more details.

To simplify the upload, we created a helper script named **uploadHelper.sh**. Initiate the upload by following the instructions below:
1) Open a terminal and change directory to the cloned repository.
2) Run ```chmod +x uploadHelper.sh```.
3) Run ```./uploadHelper.sh <bucket_name> <key_prefix>```. This will upload the files to S3.
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
          |       |      +-- hardening_bootstrap.sh
          |       |      +-- helmAcs.sh
          |       |      +-- helmFluentd.sh
          |       |      +-- helmIngress.sh
          |       |      +-- helmInit.sh
          |       |-- templates
          |       |      |-- acs.yaml
          |       |      +-- acs-deployment-master.yaml
          |       |      +-- acs-master-parameters.json
          |       |      +-- bastion-and-eks-cluster.yaml
          |       |      +-- efs.yaml
          |       |      +-- mq.yaml
          |       |      +-- rds.yaml
          |       |      +-- s3-bucket.yaml
```

## Deploying ACS EKS with AWS Console
To use the AWS Console, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

* Go to the **AWS Console** and open **CloudFormation**.
* Click ```Create Stack```.
* In ```Upload a template to Amazon S3``` choose `templates/acs-deployment-master.yaml`.
* Choose a stack name, for example, `my-acs-eks`.
* Fill in the parameters in each of the configuration sections.

In many cases you can use the default parameters. Additional information is provided for some parameter sections, including a list of mandatory parameters below:
* Availability Zones
* Key Pair Name
* RDS Password
* CIDR block to allow remote access
* Alfresco Password
* AmazonMQ Password
* The name of the S3 bucket that holds the templates
* The ACS domain name
* The ACS SSL Certificate arn to use with ELB
* Private Registry Credentials
* The hosted zone to create Route53 Record for ACS

See the AWS documentation on [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for details on how to create a key pair name.

**VPC Stack Configuration**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| The AZ's to deploy to. (AvailabilityZones)| <span style="color:red">Requires input</span> | List of Availability Zones to use for the subnets in the VPC. Please choose two or more zones. |
| The key pair name to use to access the instances (KeyPairName)| <span style="color:red">Requires input</span> | The name of an existing public/private key pair, which allows you to securely connect to your instance after it launches |
| The CIDR block for the first private subnet (PrivateSubnet1CIDR)| 10.0.0.0/19 | CIDR block for private subnet 1 located in Availability Zone 1 |
| The CIDR block for the second private subnet (PrivateSubnet2CIDR)| 10.0.32.0/19 | CIDR block for private subnet 1 located in Availability Zone 2 |
| The CIDR block for the first public subnet (PublicSubnet1CIDR)| 10.0.128.0/20 | CIDR block for the public (DMZ) subnet 1 located in Availability Zone 1 |
| The CIDR block for the second public subnet (PublicSubnet2CIDR)| 10.0.144.0/20 | CIDR block for the public (DMZ) subnet 2 located in Availability Zone 2 |
| The CIDR block for the VPC to create (VPCCIDR)| 10.0.0.0/16 | CIDR block for the VPC |

**Bastion and EKS Cluster Stack Configuration**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| The CIDR block to allow remote access (RemoteAccessCIDR)| <span style="color:red">Requires input</span> | The CIDR IP range that is permitted to access the AWS resources. It is recommended that you set this value to a trusted IP range. For example <my_ip>/32 |
| The instance type to deploy Bastion to (BastionInstanceType)| t2.micro | The type of EC2 instance to be launched for Bastion Host |
| The maximum number of nodes to scale up to for Bastion (MaxNumberOfBastionNodes)| 1 | The maximum number of Bastion instances to run |
| The minimum number of nodes to scale down to for Bastion (MinNumberOfBastionNodes)| 1 | The minimum number of Bastion instances to run |
| The desired number of nodes to keep running for Bastion (DesiredNumberOfBastionNodes)| 1 | The desired number of Bastion instance to run |
| The instance type to deploy EKS Worker Node to (NodeInstanceType)| m5.xlarge | The type of EC2 instance to be launched for EKS Worker Node |
| The maximum number of nodes to scale up to for EKS Worker Node (MaxNumberOfNodes)| 3 | The maximum number of EKS Worker Nodes to run |
| The minimum number of nodes to scale down to for EKS Worker Node (MinNumberOfNodes)| 2 | The minimum number of EKS Worker Nodes to run |
| The desired number of nodes to keep running for EKS Worker Node (DesiredNumberOfNodes)| 2 | The desired number of EKS Worker Nodes to run |
| Enables all CloudWatch metrics for the nodes auto scaling group (NodesMetricsEnabled)| false | Enables all CloudWatch metrics for the nodes auto scaling group |
| The AWS IAM user arn who will be authorised to connect the cluster externally (EksExternalUserArn)| "" | The AWS IAM user arn who will be authorised to connect the cluster externally |
| The namespace in EKS to deploy Helm charts (K8sNamespace)| acs | The namespace in EKS to deploy Helm charts |
| Size in GB for the Index EBS volume (IndexEBSVolumeSize)| 100 | Size in GB for the Index EBS volume |
| IOPS for the Index EBS volume (300 to 20000) (IndexEBSIops)| 300 | IOPS for the Index EBS volume (300 to 20000) |

**S3 Cross Replication Bucket for storing ACS content store**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| Enable Cross Region Replication for this Bucket (UseCrossRegionReplication) | false | Set to true if you want to add an S3 Bucket for replication. See the AWS documentation on [Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/dev/crr.html) for more information. |
| Destination Bucket region (ReplicationBucketRegion)| eu-west-1 | The Region of the Replication bucket |
| Destination Replication Bucket (ReplicationBucket)| "" | Name of the destination S3 Bucket you want to replicate data into. |
| Destination Bucket KMS Encryption Key (ReplicationBucketKMSEncryptionKey)| "" | The KMS encryption key for the destination bucket |

**Alfresco Storage Configuration**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| RDS Instance Type (RDSInstanceType)| db.r4.xlarge | EC2 instance type for the Amazon RDS instances |
| RDS Allocated Storage (RDSAllocatedStorage)| 5 | Size in GiB for the Amazon RDS MySQL database allocated storage (only non-Amazon Aurora region) |
| RDS DB Name (RDSDBName)| alfresco | DB name for the Amazon RDS Aurora database (MySQL if non-Amazon Aurora region). |
| RDS User Name (RDSUsername)| alfresco | User name for the Amazon RDS database |
| RDS Password (RDSPassword)| <span style="color:red">Requires input</span> | Password for the Amazon RDS database |
| Creates a snapshot when the stack gets deleted (RDSCreateSnapshotWhenDeleted)| true | Creates a snapshot when the stack gets deleted |

**Alfresco Broker Configuration**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| AmazonMQ Host Instance Type (MQInstanceType) | mq.m5.large | The broker's instance type |
| AmazonMQ Deployment mode (MQDeploymentMode) | ACTIVE_STANDBY_MULTI_AZ | The deployment mode of the broker |
| AmazonMQ User Name (MQUsername) | admin | User name for the AmazonMQ |
| AmazonMQ Password (MQPassword) | <span style="color:red">Requires input</span> | Password for the AmazonMQ. Minimum 12 characters. |

**ACS Stack Configuration**

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| The name of the S3 bucket that holds the templates (TemplateBucketName)| <span style="color:red">Requires input</span> | Take the `bucket_name` from the upload step. |
| The Key prefix for the templates in the S3 template bucket (TemplateBucketKeyPrefix)| development | Take the `key_prefix` from the upload step. |
| The namespace in EKS to deploy Helm charts (K8sNamespace)| acs | The namespace in EKS to deploy Helm charts |
| The ACS SSL Certificate arn to use with ELB (ElbCertArn)| <span style="color:red">Requires input</span> | Take the SSL certificate arn for your domains in the hosted zone, e.g. `arn:aws:acm:us-east-1:1234567890:certificate/a08b75c0-311d-4999-9995-39fefgh519i9`. For more information about how to create SSL certificates, see the AWS documentation on the [AWS Certificate Manager](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html). |
| The ACS SSL Certificate policy to use with ELB (ElbCertPolicy)| ELBSecurityPolicy-TLS-1-2-2017-01 | The ACS SSL Certificate policy to use with ELB |
| The ACS domain name (AcsExternalName)| <span style="color:red">Requires input</span> | Choose the domain name which will be used as the entry URL, e.g. **my-acs-eks.example.com**. The domain name consists of ```<subdomain-name>.<hosted-zone-name>```. For more information about how to create a hosted zone and its subdomains, see the AWS documentation on [Creating a Subdomain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html). |
| The nginx-ingress chart version (NginxIngressVersion)| 0.14.0 | The nginx-ingress chart version |
| The helm chart release name of nginx-ingress (IngressReleaseName)| ingress | The helm chart release name of nginx-ingress |
| The helm chart release name of alfresco content services (AcsReleaseName)| acs | The helm chart release name of alfresco content services |
| The Admin password for Alfresco (AlfrescoPassword)| <span style="color:red">Requires input</span> | The Admin password for Alfresco |
| Private Registry Credentials. Base64 encryption of dockerconfig json (RegistryCredentials)| <span style="color:red">Requires input</span> | Make sure you have your Quay.io credentials as described in the [Prerequisites](#prerequisites). Also, if you're using Docker for Mac, go to **Preferences...** > **General** to ensure your "Securely store docker logins in macOS keychain" preference is OFF before running the next step.<ol><li> Login to quay.io: <br>```docker login quay.io```</li> <li> Validate that you can see the credentials for Quay.io: <br>```cat ~/.docker/config.json```</li><li> Get the encoded credentials: <br>```cat ~/.docker/config.json \| base64```</li><li> Copy the credentials into the textbox.</li></ol> |
| The number of repository pods in the cluster (RepoPods)| 2 | The number of repository pods in the cluster |
| The hosted zone to create Route53 Record for ACS (Route53DnsZone)| <span style="color:red">Requires input</span> | Enter your hosted zone e.g. **example.com.**. For more information about how to create a hosted zone, see the AWS documentation on [Creating a Public Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html). |

After the CFN stack creation has finished, you can find the Alfresco URL in the output from the master template.

### Upgrading the ACS helm deployment with CFN templates
This section describes how to perform a Helm upgrade using the CFN template update feature in the AWS Console. Alternatively, you can manually upgrade the ACS Helm charts by establishing a connection to the cluster (see [EKS cluster remote access](docs/eks_cluster_remote_access.md)) or using the bastion host (see [How to connect ACS bastion host remotely](docs/bastion_access.md)).

**Note:**
* Upgrading using the CFN update template is only possible to version 1.1.8.2 or later.
* Downgrading to an older ACS Helm chart is not supported.
* If the upgrade fails, Helm will revert to the previous chart version.

#### Upgrade steps
1. Choose the CFN template version you would like to upgrade to from the [Releases](https://github.com/Alfresco/acs-deployment-aws/releases) page. Make sure it is 1.1.10 or newer. Also, check the [Changelog](CHANGELOG.md) for the chosen version to see the feature updates in each release.
2. Checkout your git deployment to this commit or download and unzip the release artefact.
3. Change directory to
```acs-deployment-aws```
.
4. Prepare an S3 bucket to upload all the required files, like nested templates, scripts, lambdas. You can simply follow the same steps as in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment). The `<bucket_name>` and `<key_prefix>` don’t need to be the same as during the first deployment of ACS EKS, but make sure that the bucket resides in the same region as your ACS deployment.
5. Go to the **AWS Console** and open **CloudFormation**.
6. Check the master stack from your ACS deployment (it starts with the description: Master template to deploy ACS ...)
7. Click on
```Actions```
and then on
```Update Stack```
.
8. In
```Upload a template to Amazon S3```
choose `acs-deployment-aws/templates/acs-deployment-master.yaml` and click
```Next```
.
9. In the
```ACS Stack Configuration```
section, provide the bucket name for the first parameter labeled with
```The name of the S3 bucket that holds the templates```
, and the key prefix for the second parameter labeled with
```The Key prefix for the templates in the S3 template bucket```
from step 4.
10. Click
```Next```
and update any additional options for your stack (if needed).
11. Click
```Next```
and check the change details.
12. Check the Capabilities that are needed for the update.
13. Click on
```Update```
.

The whole CFN update process takes some minutes. You can follow the update process by looking at the **Status** column in CloudFormation. Validate that the deployment is using the newer chart versions by establishing a connection to the cluster ([EKS cluster remote access](docs/eks_cluster_remote_access.md)) or using the bastion host ([How to connect ACS bastion host remotely](docs/bastion_access.md)) and execute:

```bash
helm ls
```

**Troubleshooting:**
* If the stack fails to update due to problems with a lambda function, use the CloudWatch logs to identify the problem.
* If there is not enough information, go to the created EC2LogGroup (in the CloudFormation stack) and search for the Bastion log stream ending with
```amazon-ssm-agent.log```
to get more detailed log information.

### Deleting ACS EKS with AWS Console
Go to **CloudFormation** and delete the master ACS EKS stack. The nested stacks will be deleted first, followed by the master stack.


## Deploying ACS EKS with AWS Cli
**Note:** To use the Cli, make sure that you've uploaded the required files to S3 as described in [Preparing the S3 bucket for CFN template deployment](#preparing-the-s3-bucket-for-cfn-template-deployment).

### Prerequisites

To run the Alfresco Content Services (ACS) deployment on an AWS provided Kubernetes cluster requires:

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

See the AWS documentation on [Amazon EC2 Key Pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for details on how to create a key pair name.

### Deleting ACS EKS with AWS Cli
Open a terminal and enter:
```
aws cloudformation delete-stack --stack-name <master-acs-eks-stack>
```

## Cluster bastion access
To access the cluster using the deployed bastion, follow the instructions in [How to connect ACS bastion host remotely](docs/bastion_access.md).

## Cluster remote access
### Prerequisites

To access the Alfresco Content Services (ACS) deployment on an AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| Kubectl     | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| IAM User    | https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html |

Follow the detailed instructions in [EKS cluster remote access](docs/eks_cluster_remote_access.md).

# License information
* The ACS images downloaded directly from hub.docker.com, or Quay.io are for a limited trial of the Enterprise version of Alfresco Content Services that goes into read-only mode after 2 days. Request an extended 30-day trial at https://www.alfresco.com/platform/content-services-ecm/trial/docker.
* To extend the trial license period and apply it to your running system, follow the steps in [Uploading a new license](http://docs.alfresco.com/6.0/tasks/at-adminconsole-license.html).
* If you plan to use the AWS deployment in production, you need to get an Enterprise license in order to use the S3 Connector AMP.
