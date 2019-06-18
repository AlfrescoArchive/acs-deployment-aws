# 2.0.0.1

## Fixes
* S3 VPC template path fix

# 2.0.0

## Features
* Using Alfresco's Helm Charts 2.0.0 https://github.com/Alfresco/acs-deployment
* Added optional CFN parameter (RepoImage, RepoTag, ShareImage, ShareTag) for customized Alfresco Repository & Share docker images  . If not specified the Helm Chart values are taken.

## Fixes
* Allow communication across worker nodes

# 1.1.10

## Features
* Using Alfresco's Helm Charts 1.1.10 https://github.com/Alfresco/acs-deployment

# 1.1.8.2

## Features
* Implemented life cycle policy to create a daily snapshot from the EBS solr volume
* Use CFN update template to upgrade ACS helm chart version

# 1.1.8.1

## Features
* Use AmazonMQ as message broker

# 1.1.8

## Features
* Using Alfresco's Helm Charts 1.1.8 https://github.com/Alfresco/acs-deployment
* Using AWS EBS for Solr
* Adding FluentD logging capabilities

# 1.0.0-EA2

## Features
* Includes the <a href='docs/transform-services.md'>Transform Service</a> that performs transformations for Alfresco Content Services remotely in scalable containers.

# 1.0.0-EA

## Features
* CFN template for creating AWS resources EKS, EC2, EFS, RDS, S3, Lambda
* Enhanced ACR image for including S3 Connector amp and MariaDB driver
* Using Alfresco's Helm Charts for configuring Kubernetes
* Use RDS as relational DB, EFS as filesystem for Solr and S3 as storage for alf_data