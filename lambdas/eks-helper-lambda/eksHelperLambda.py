import boto3
import logging
import cfnresponse
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

eks_client = boto3.client('eks')

def handler(event, context):
    '''Main handler function for EKS Cluster'''

    try:
        eventType = event['RequestType']
        physicalResourceId = str(uuid.uuid1()) if eventType == 'Create' else event['PhysicalResourceId']
        
        if eventType == 'Create' or eventType == 'Update':
            logger.info('Events received: {event}'.format(event=event))
            data = {}
            response = eks_client.describe_cluster( name=str(event['ResourceProperties']['EKSName']) )
            data['endpoint'] = str(response['cluster']['endpoint'])
            cfnresponse.send(event, context, cfnresponse.SUCCESS, data, physicalResourceId)

        if eventType == 'Delete':
            logger.info('Events received: {event}'.format(event=event))
            response = eks_client.delete_cluster( name=str(event['ResourceProperties']['EKSName']) )
            logger.info('EKS Cluster delete command executed successfully')
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, physicalResourceId)

    except Exception as err:
        logger.error('EKS Helper lambda Error: "{type}": "{message}"'.format(type=type(err), message=str(err)))
        cfnresponse.send(event, context, cfnresponse.FAILED, {})
