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

### How to deploy ACS Cluster on AWS
[Create Cluster](./docs/eks_create_cluster.md)

* Docker Alfresco
The private image is published on:
https://quay.io/repository/alfresco/alfresco-content-repository?tab=tags

For testing locally:
1. Go to docker-alfresco folder
2. Run ```mvn clean install``` if you have not done so
3. Build the docker image: ```docker build . --tag acr-aws:6.0.tag```
4. Check that the image has been created locally, with your desired name/tag: ```docker images```

More technical documentation is available inside [docs](docs/).