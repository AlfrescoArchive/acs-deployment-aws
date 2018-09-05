# EKS create cluster

## Create cluster with Bamboo
The recommended way to create an ACS EKS cluster is to use Bamboo.

* Create remote branch with name `feature/abc` . Bamboo will create the cluster for you.

* Check in Cloudformation with Amazon Console if the stack is finished.

## Create cluster without Bamboo
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

* Validate master acs-deployment template before creating the cluster
```bash
aws cloudformation validate-template --template-body file://templates/acs-deployment-master.yaml
```
**Note**: This should not complain of any errors, if so then do not proceed and debug errors.

* Create an s3 bucket to store sub-stack cloudformation templates, scripts and lambdas
```bash
$ aws s3 mb s3://my-bucket-name
``` 

* Copy templates in the bucket
```bash
export S3_BUCKET=my-bucket-name
export S3_KEY_PREFIX=development
aws s3 cp ./templates s3://$S3_BUCKET/$S3_KEY_PREFIX/templates --recursive
aws s3 cp ./scripts s3://$S3_BUCKET/$S3_KEY_PREFIX/scripts --recursive
aws s3 cp ./lambdas/eks-helper-lambda/eks-helper-lambda.zip s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/
aws s3 cp ./lambdas/helm-helper-lambda/helm-helper-lambda.zip s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/
aws s3 cp ./lambdas/empty-s3-bucket/alfresco-lambda-empty-s3-bucket.jar s3://$S3_BUCKET/$S3_KEY_PREFIX/lambdas/

```
* Create acs-deployment stack
```bash
aws cloudformation create-stack \
  --stack-name my-acs-stack \
  --template-body file://templates/acs-deployment-master.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=KeyPairName,ParameterValue=<MyKey.pem> \
               ParameterKey=AvailabilityZones,ParameterValue=us-east-1a\\,us-east-1b \
               ParameterKey=RemoteAccessCIDR,ParameterValue=<C.I.D.R/32> \
               ParameterKey=TemplateBucketName,ParameterValue=my-bucket-name \
               ParameterKey=TemplateBucketKeyPrefix,ParameterValue=development \
               ParameterKey=EksExternalUserArn,ParameterValue=arn:aws:iam::<AccountId>:user/<IamUser> \
               ParameterKey=AcsExternalName,ParameterValue=alfresco \
               ParameterKey=RDSPassword,ParameterValue=<password> \
               ParameterKey=Route53DnsZone,ParameterValue=<dnsZone> \
               ParameterKey=ElbCertArn,ParameterValue=arn:aws:acm:us-east-1:<AccountId>:certificate/<elbCertId>          
```

This should take some time to complete the ACS Deployment. You can see the status of stacks in AWS Console. Once the stack if successfully completed, several stack Outputs and available.

