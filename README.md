# Alfresco Content Services Deployment on AWS Cloud

## Overview

This project contains the code for the AWS based Alfresco Content Services (Enterprise) product on AWS Cloud using Cloudformation template.  It is build with a main cloudformation template that will also spin sub-stacks for VPC, Bastion Host, EKS Cluster and Worker Nodes (including registering them with EKS Master) in an auto-scaling group.

## Prerequisites

To run the Alfresco Content Services (ACS) deployment on AWS provided Kubernetes cluster requires:

| Component   | Getting Started Guide |
| ------------| --------------------- |
| Kubectl     | https://kubernetes.io/docs/tasks/tools/install-kubectl/ |
| AWS Cli     | https://github.com/aws/aws-cli#installation |

**Note:** You need to clone this repository to deploy Alfresco Content Services.

## Limitations

This setup will work as of now only in AWS US East (N.Virginia), West (Oregon) and EU (Ireland) regions due to current EKS support.


# How to deploy ACS Cluster on AWS
### Prerequisites
* You need a hosted zone e.g. example.com.  [Creating Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
* An SSL certificate for the Elastic Load Balancer and the domains in the hosted zone [Creating SSL Cert](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html)
* An IAM user for directly accessing the EKS cluster [Creating IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

### Permissions
Ensure that the IAM Role or IAM user which is creating the stack allows the following permissions:

ec2:AssociateAddress \
ec2:DescribeAddresses

eks:*

iam:PassRole

kms:Decrypt \
kms:Encrypt
                  
logs:CreateLogStream \
logs:GetLogEvents \
logs:PutLogEvents \
logs:DescribeLogGroups \
logs:DescribeLogStreams \
logs:PutRetentionPolicy \
logs:PutMetricFilter \
logs:CreateLogGroup
     
s3:GetObject \
s3:GetReplicationConfiguration \
s3:ListBucket \
s3:GetObjectVersionForReplication \
s3:GetObjectVersionAcl \
s3:ReplicateObject
                  
sts:*

## Upload step
The master template (templates/acs-deployment-master.yaml) requires a couple of in S3 uploaded files like lambdas, scripts and cfn templates. For doing so please create or use an S3 bucket. As well the S3 bucket needs to have an key prefix in it:
```s3://<bucket_name>/<key_prefix>``` e.g. ```s3://my-s3-bucket/development```

**Note:** With S3 in AWS Console you can create the <key_prefix> with creating a folder.

For simplifying the upload we created a helper script named uploadHelper.sh which only will work with Mac or Linux. For Windows please upload those files manually or execute the aws commands from the script in CMD. Please initiate the upload with doing the following instructions:
1) Open terminal and change the dir to the cloned repository.
2) ```chmod +x uploadHelper.sh```
3) ```./uploadHelper.sh <bucket_name> <key_prefix>``` . This will upload the files to S3.
4) Please check if the bucket has the following files:

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

### Deploy ACS EKS with AWS Console
**Note:** For using the AWS Console make sure that you uploaded the needed files to S3 how described in the [Upload Step](#upload-step)!

* Go to AWS Console and open CloudFormation
* Click on ```Create Stack```
* In: ```Upload a template to Amazon S3``` choose templates/acs-deployment-master.yaml
* Choose a stack name like my-acs-eks
* Fill out the parameters. In many cases you can take the default parameter. For some parameter sections
we will provide some extra information.

**S3 Cross Replication Bucket for storing ACS content store**

```Enable Cross Region Replication for This Bucket``` : Cross Region Replication replicates your data into an other bucket. Please visit [CRR](https://docs.aws.amazon.com/AmazonS3/latest/dev/crr.html) for more information.

**ACS Stack Configuration**

```The name of the S3 bucket that holds the templates``` : Take the bucket name from the upload step.

```The Key prefix for the templates in the S3 template bucket``` : Take the key_prefix upload step.

```The ACS SSL Certificate arn to use with ELB``` : Take the SSL certificate arn for your domains in the hosted zone.

```The ACS external endpoint name``` : Choose the available endpoint which will be used for the url e.g. **my-acs-eks.example.com** 

```Private Registry Credentials. Base64 encryption of dockerconfig json``` : 
1) Login to quay.io with ```docker login quay.io```.
2) Validate that you can see the credentials with ```cat ~/.docker/config.json``` for quay.io.
3) Get the encoded credentials with ```cat ~/.docker/config.json | base64```.
4) Copy them into the textbox.

```The hosted zone to create Route53 Record for ACS``` : Enter your hosted zone e.g. **example.com.**


### Deploy ACS EKS with AWS CLI
**Note:** For using the CLI make sure that you uploaded the needed files to S3 how described in the [Upload Step](#upload-step)!

Create ACS EKS with using the the [cloudformation command](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html). Make sure that you use the same bucket name and key prefix in the CLI command as you used in the [Upload Step](#upload-step)!

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
               ParameterKey=RDSPassword,ParameterValue=<password> \
               ParameterKey=Route53DnsZone,ParameterValue=<dnsZone> \
               ParameterKey=ElbCertArn,ParameterValue=arn:aws:acm:us-east-1:<AccountId>:certificate/<elbCertId>
```

### Delete ACS EKS with AWS Console
Go to Cloudformation and delete the master acs eks stack. The nested stacks will be deleted first and at the end the master stack.

### Delete ACS EKS with AWS CLI
Open a terminal an enter:
```
aws cloudformation delete-stack --stack-name <master-acs-eks-stack>
```

# Modified ACR docker images
With the goal to use AWS services like RDS or S3 you need to enhance the basic ACR docker image distributed on:
https://hub.docker.com/r/alfresco/alfresco-content-repository or \
https://quay.io/repository/alfresco/alfresco-content-repository

The sub module /docker-alfresco provides a sub project to do the modifications.

Those modifications currently containing:
* added mariadb-java-client-2.2.6.jar driver for connecting to Aurora MySql
* installed alfresco-s3-connector-2.2.0.amp for storing the alf_data inside of an S3 bucket

The official modified ACR docker images will be published on:
https://hub.docker.com/r/alfresco/alfresco-content-repository-aws and \
https://quay.io/repository/alfresco/alfresco-content-repository-aws

Once a new image is created it can be picked up as part of the helm deploy in
scripts/helmAcs.sh
```
--set repository.image.repository="quay.io/alfresco/alfresco-content-repository-aws" \
--set repository.image.tag="0.1.1-repo-6.0.0" \
```

## Testing the modified images locally
1. Go to docker-alfresco folder
2. Run ```mvn clean install``` if you have not done so
3. Build the docker image: ```docker build . --tag acr-aws:6.0.tag```
4. Check that the image has been created locally, with your desired name/tag: ```docker images```

More technical documentation is available inside [docs](docs/).

# Other information
If you are using one of our enterprise ACR base images from hub.docker.com or quay.io please keep in mind that Alfresco Content Services goes into read-only mode after 2-days. Request an extended 30-day trial at https://www.alfresco.com/platform/content-services-ecm/trial/docker
