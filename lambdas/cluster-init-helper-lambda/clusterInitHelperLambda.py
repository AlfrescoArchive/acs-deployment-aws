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
        physicalResourceId = str(uuid.uuid1()) if eventType == 'Create' else event['PhysicalResourceId']

        # Get EC2 instances to run SSM commands document
        ssm_instance = ec2_instanceId(event['ResourceProperties']['BastionAutoScalingGroup'])

        logger.info('Events received: {event}'.format(event=event))

        # Dict to return lambda outputs
        data = {}

        if eventType == 'Create':
            # First download all helper scripts
            init_doc = describe_document(event['ResourceProperties']['HelmDownloadScript'])
            logger.info('Downloading helper scripts...')
            init = ssm_sendcommand(ssm_instance, init_doc['Name'], {})
            if ssm_commandstatus(init['CommandId'], ssm_instance) is True:
                logger.info('scripts directory was downloaded successfully!')

                # Execute scripts to setup helm deployment
                helminit_doc = describe_document(event['ResourceProperties']['HelmInitRunScript'])
                helmfluentd_doc = describe_document(event['ResourceProperties']['HelmInstallFluentdRunScript'])
                helmautoscaler_doc = describe_document(event['ResourceProperties']['HelmInstallAutoscalerRunScript'])

                if helminit_doc['Status'] == 'Active' and helmfluentd_doc['Status'] == 'Active' and helmautoscaler_doc['Status'] == 'Active':

                    # Deploy Tiller with Helm init
                    logger.info('Initialising helm...')
                    helminit = ssm_sendcommand(ssm_instance, helminit_doc['Name'], {})
                    if ssm_commandstatus(helminit['CommandId'], ssm_instance) is True:
                        logger.info('Tiller was deployed successfully!')

                        # Deploy Fluentd helm chart
                        logger.info('Installing fluentd...')
                        helmdeployfluentd = ssm_sendcommand(ssm_instance, helmfluentd_doc['Name'], {})
                        if ssm_commandstatus(helmdeployfluentd['CommandId'], ssm_instance) is True:
                            logger.info('Fluentd installation completed successfully!')

                            # Deploy Cluster Autoscaler helm chart
                            logger.info('Installing cluster autoscaler...')
                            helmdeployautoscaler = ssm_sendcommand(ssm_instance, helmautoscaler_doc['Name'], {})
                            if ssm_commandstatus(helmdeployautoscaler['CommandId'], ssm_instance) is True:
                                logger.info('Cluster Autoscaler completed successfully!')

                                logger.info('Signalling success to CloudFormation...')
                                cfnresponse.send(event, context, cfnresponse.SUCCESS, data, physicalResourceId)
                            else:
                                logger.error('Cluster Autoscaler installation was unsuccessful')
                                cfnresponse.send(event, context, cfnresponse.FAILED, {})
                        else:
                            logger.error('Fluentd installation was unsuccessful')
                            cfnresponse.send(event, context, cfnresponse.FAILED, {})
                    else:
                        logger.error('Tiller deployment was unsuccessful')
                        cfnresponse.send(event, context, cfnresponse.FAILED, {})
                else:
                    logger.error('SSM commands are not active')
                    cfnresponse.send(event, context, cfnresponse.FAILED, {})
            else:
                logger.error('Helper scripts download was unsuccessful')
                cfnresponse.send(event, context, cfnresponse.FAILED, {})
        else:
            logger.info('Nothing to do for update or delete, signalling success to CloudFormation...')
            cfnresponse.send(event, context, cfnresponse.SUCCESS, data, physicalResourceId)

    except Exception as err:
        logger.error('Cluster Init Helper Lambda Error: "{type}": "{message}"'.format(type=type(err), message=str(err)))
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
        STATUS = "InProgress"
        while STATUS == "InProgress":
            time.sleep(1)
            output = ssm_commandoutput(command_id, instance_id)
            STATUS = output['Status']
        if output['Status'] == 'Success' and output['ResponseCode'] == 0:
            return True
    except Exception as err:
        logger.error('SSM Command Status error - "{type}": "{message}"'.format(type=type(err), message=str(err)))
        return err