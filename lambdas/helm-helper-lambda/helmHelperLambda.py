import boto3
import os
import json
import logging
import cfnresponse
import uuid
import time

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm_client = boto3.client('ssm')
ec2_client = boto3.client('ec2')

def handler(event, context):
    '''Main handler function for Helm deployment'''
  
    try:
        eventType = event['RequestType']
        physicalResourceId = str(uuid.uuid1()) if eventType == 'Create' or eventType == 'Update' or eventType == 'Delete' else event['PhysicalResourceId']
  
        # Get EC2 instances to run SSM commands document
        ssm_instance = ec2_instanceId(event['ResourceProperties']['BastionAutoScalingGroup'])
        
        if eventType == 'Create' or eventType == 'Update':
            logger.info('Events received: {event}'.format(event=event))

            # Dict to return lambda outputs
            data = {}

            # First download all helper scripts
            init_doc = describe_document(event['ResourceProperties']['HelmInitDownloadScript'])
            init = ssm_sendcommand(ssm_instance, init_doc['Name'], {})
            if ssm_commandstatus(init['CommandId'], ssm_instance) is True:
                logger.info('HelmInitDownloadScript was downloaded successfully!')
                
            installingress_doc = describe_document(event['ResourceProperties']['HelmInstallIngressDownloadScript'])
            installingress = ssm_sendcommand(ssm_instance, installingress_doc['Name'], {})
            if ssm_commandstatus(installingress['CommandId'], ssm_instance) is True:
                logger.info('HelmInstallIngressDownloadScript was downloaded successfully!')

            installacs_doc = describe_document(event['ResourceProperties']['HelmInstallAcsDownloadScript'])
            installacs = ssm_sendcommand(ssm_instance, installacs_doc['Name'], {})
            if ssm_commandstatus(installacs['CommandId'], ssm_instance) is True:
                logger.info('HelmInstallAcsDownloadScript was downloaded successfully!')

            upgradeacs_doc = describe_document(event['ResourceProperties']['HelmUpgradeAcsDownloadScript'])
            upgradeacs = ssm_sendcommand(ssm_instance, upgradeacs_doc['Name'], {})
            if ssm_commandstatus(upgradeacs['CommandId'], ssm_instance) is True:
                logger.info('HelmUpgradeAcsDownloadScript was downloaded successfully!')

            getelb_doc = describe_document(event['ResourceProperties']['GetElbEndpointDownloadScript'])
            getelb = ssm_sendcommand(ssm_instance, getelb_doc['Name'], {})
            if ssm_commandstatus(getelb['CommandId'], ssm_instance) is True:
                logger.info('GetElbEndpointDownloadScript was downloaded successfully!')
                        
            # Execute scripts to setup ACS
            helminit_doc = describe_document(event['ResourceProperties']['HelmInitRunScript'])
            helmingress_doc = describe_document(event['ResourceProperties']['HelmInstallIngressRunScript'])
            helmacsinstall_doc = describe_document(event['ResourceProperties']['HelmInstallAcsRunScript'])
            helmacsupgrade_doc = describe_document(event['ResourceProperties']['HelmUpgradeAcsRunScript'])
            helmelb_doc = describe_document(event['ResourceProperties']['GetElbEndpointRunScript'])
        
            if helminit_doc['Status'] == 'Active' and helmingress_doc['Status'] == 'Active' and helmacsinstall_doc['Status'] == 'Active':
        
                # Deploy Tiller with Helm init 
                helminit = ssm_sendcommand(ssm_instance, helminit_doc['Name'], {})
                if ssm_commandstatus(helminit['CommandId'], ssm_instance) is True:
                    logger.info('Tiller was deployed successfully!')
        
                    # Deploy nginx-ingress helm chart
                    helmingress = ssm_sendcommand(ssm_instance, helmingress_doc['Name'], {})
                    if ssm_commandstatus(helmingress['CommandId'], ssm_instance) is True:
                        logger.info('Nginx-ingress deployed successfully!')
        
                        if eventType == 'Create':
                            # Install ACS helm chart
                            helmacs = ssm_sendcommand(ssm_instance, helmacsinstall_doc['Name'], {})
                            if ssm_commandstatus(helmacs['CommandId'], ssm_instance) is True:
                                logger.info('ACS installation completed successfully!')
                            else:
                                logger.error('ACS installation was unsuccessful')
                                cfnresponse.send(event, context, cfnresponse.FAILED, {})
        
                        if eventType == 'Update':
                            # Upgrade ACS helm chart
                            helmacs = ssm_sendcommand(ssm_instance, helmacsupgrade_doc['Name'], {})
                            if ssm_commandstatus(helmacs['CommandId'], ssm_instance) is True:
                                logger.info('ACS upgrade completed successfully!')
                            else:
                                logger.error('ACS upgrade was unsuccessful')
                                cfnresponse.send(event, context, cfnresponse.FAILED, {})
        
                        # Get ACS ELB to return as Stack Output
                        helmelb = ssm_sendcommand(ssm_instance, helmelb_doc['Name'], {})
                        if ssm_commandstatus(helmelb['CommandId'], ssm_instance) is True:
                            logger.info('Got ACS ELB successfully!')
                            helmelb_output = ssm_commandoutput(helmelb['CommandId'], ssm_instance)
                            data['elb'] = helmelb_output['StandardOutputContent'].rstrip('\n')
                        else:
                            logger.error('ACS Get Elb command was unsuccessful')
                            cfnresponse.send(event, context, cfnresponse.FAILED, {})
                    else:
                        logger.error('Nginx-ingress deployment was unsuccessful')
                        cfnresponse.send(event, context, cfnresponse.FAILED, {})
                else:
                    logger.error('Tiller deployment was unsuccessful')
                    cfnresponse.send(event, context, cfnresponse.FAILED, {})
            cfnresponse.send(event, context, cfnresponse.SUCCESS, data, physicalResourceId)
        
        if eventType == 'Delete':
            logger.info('Events received: {event}'.format(event=event))

            deleteingress_doc = describe_document(event['ResourceProperties']['HelmDeleteIngressDownloadScript'])
            deleteingress = ssm_sendcommand(ssm_instance, deleteingress_doc['Name'], {})
            if ssm_commandstatus(deleteingress['CommandId'], ssm_instance) is True:
                logger.info('HelmDeleteIngressDownloadScript was downloaded successfully!')

            # Delete nginx-ingress ELB as it is not fully managed by CFN
            helmdel_doc = describe_document(event['ResourceProperties']['HelmDeleteIngressRunScript'])
            helmdel = ssm_sendcommand(ssm_instance, helmdel_doc['Name'], {})
            if ssm_commandstatus(helmdel['CommandId'], ssm_instance) is True:
                logger.info('Nginx-ingress chart purged successfully!')
        
            # Revoke elb SecurityGroup rule from node sg and then delete elb SecurityGroup created by nginx-ingess
            sgId = describe_sg(event['ResourceProperties']['VPCID'], event['ResourceProperties']['EKSName'])
            revoke_ingress(event['ResourceProperties']['NodeSecurityGroup'], sgId)

            # Dirty hack to force SG delete.  It takes some time after revoking a rule from a dependent SG.
            STATUS = sgId
            for i in range(0,100):
                while STATUS != sgId:
                    time.sleep(1)
                    delete_sg(sgId)
                    STATUS = describe_sg(event['ResourceProperties']['VPCID'], event['ResourceProperties']['EKSName'])

            logger.info('SG deleted successfully created by nginx-ingress')
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, physicalResourceId)
  
    except Exception as err:
        logger.error('Helm Helper lambda Error: "{type}": "{message}"'.format(type=type(err), message=str(err)))
        cfnresponse.send(event, context, cfnresponse.FAILED, {})

def describe_document(doc_name):
    '''A function to return SSM Document details'''
    try:
        response = ssm_client.describe_document( Name=doc_name )
        return response['Document']
    except Exception as err:
        logger.error('SSM Document Describe error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def ec2_instanceId(autoscaling):
    '''A function to return SSM managed EC2 instances'''
    try:
        response = ec2_client.describe_instances( 
                        Filters=[
                            {
                                'Name': 'tag:aws:autoscaling:groupName',
                                'Values': [autoscaling]
                            },
                            {
                                'Name': 'instance-state-name',
                                'Values': ['running']
                            }
                        ]
                    )
        return response['Reservations'][0]['Instances'][0]['InstanceId']
    except Exception as err:
        logger.error('EC2 Get Instance Id error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def ssm_sendcommand(instance_id, doc_name, params):
    '''A function to execute SSM Document on an EC2 instance'''
    try:
        response = ssm_client.send_command(
                InstanceIds=[instance_id],
                DocumentName=str(doc_name),
                Comment='helmHelperLambda triggered this',
                Parameters=params
        )
        return response['Command']
    except Exception as err:
        logger.error('SSM Send Command error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def ssm_commandoutput(command_id, instance_id):
    '''A function to return output of SSM Document'''
    try:
        response = ssm_client.get_command_invocation(
                  CommandId=command_id,
                  InstanceId=instance_id
                )
        return response
    except Exception as err:
        logger.error('SSM Command Output error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def ssm_commandstatus(command_id, instance_id):
    '''A function to return ssm command status'''
    try:
  
        STATUS = ""
        for i in range(0,100):
            while STATUS != "Success":
              	time.sleep(1)
                output = ssm_commandoutput(command_id, instance_id)
              	STATUS = output['Status']
        if output['Status'] == 'Success' and output['ResponseCode'] == 0:
            return True
    except Exception as err:
        logger.error('SSM Command Status error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def describe_sg(vpcId, eksName):
    '''A function to describe Security Group of K8s Cluster created by nginx-ingress'''
    try:
        eks_tag = 'tag' + ':' + 'kubernetes.io/cluster' + '/' + eksName
        response = ec2_client.describe_security_groups(
                        Filters=[
                            {
                                'Name': 'vpc-id',
                                'Values': [vpcId]
                            },
                            {
                                'Name': eks_tag,
                                'Values': ['owned']
                            }
                        ]
                )
        return response['SecurityGroups'][0]['GroupId']
    except Exception as err:
        logger.error('Describe security group error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def revoke_ingress(sgId, revoke_id):
    '''A function to revoke an ingress rule in a provided Security Group'''
    try:        
        response = ec2_client.revoke_security_group_ingress(
                    GroupId=sgId,
                    IpPermissions=[
                        {
                            'FromPort': -1,
                            'ToPort': -1,
                            'IpProtocol': '-1',
                            'UserIdGroupPairs': [{'GroupId': revoke_id}]
                        }
                    ]
                )
    except Exception as err:
        logger.error('Revoke ingress error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err

def delete_sg(sgId):
    '''A function to delete Security Group of K8s Cluster created by nginx-ingress'''
    try:
        response = ec2_client.delete_security_group(GroupId=sgId)
    except Exception as err:
        logger.error('Delete security group error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err
