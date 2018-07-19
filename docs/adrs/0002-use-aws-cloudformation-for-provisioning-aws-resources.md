# 2. Use AWS CloudFormation for Provisioning AWS Resources

Date: 2018-07-18

## Status

Proposed

## Context

As part of the ACS with AWS Services initiative, we are looking to use more Amazon services around our Kubernetes deployment. To do this we have to find a way to provision Amazon services like S3 buckets, EKS Cluster, Amazon MQ, Aurora DB which are outside of our current helm deployment. We have investigated 3 options for doing this provisioning.

The first option would be to use CloudFormation templates to do the provisioning.
CloudFormation would be in alignment with our AWS First company direction and it can allow us to provision all types of Amazon resources needed.
An additional plus is that we have experience working with this tool within our team.
However, CloudFormation locks us to Amazon only services and makes us have separated tools for provisioning Alfresco Content Services and the adjacent resources.

The second option is having Terraform as an outside of AWS provisioner.
Terraform allows us to provision and make use of services from different cloud providers in our solutions as well as totally unrelated services like Github, Consul, PagerDuty and more importantly Bare Metal on-prem provisioning. Terraform is also abstracting away a good part of the required metadata needed for the provisioning of resources.
However, we have limited experience in using terraform.

The final option is using kubernetes controllers to deploy Amazon resources as part of the helm deployment for acs.
Implementing kubernetes controllers for dynamically provisioning resources along with the usual kubernetes deployment for Alfresco Content Services would make us more consistent in how we deploy our applications and would ease up maintenance in the future.
However, we would still need another way for provisioning the actual kubernetes cluster and our experience in developing custom resource definitions used in kubernetes controllers is inexistent.

## Decision

We will use Amazon CloudFormation templates as it is in alignment with Alfresco's AWS First direction. Also, we have experience in developing and using this tool within the company. It also brings us closer to potentially having a quickstart template for deploying the Alfresco Digital Business Platform.

## Consequences

We are locking ourselves to Amazon provided Services and we would require a consistent effort to offer our clients more flexibility if they would want to be able to use Hybrid Cloud solutions.

Kubernetes is an extremely fast-moving segment of the market, it is possible that Amazon implements additional tooling linked to Amazon Elastic Kubernetes Service.
That would help in dynamically provisioning other services in conjunction with kubernetes so this decision may need re-visiting regularly.
