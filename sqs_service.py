import boto3
import json
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

class SQSService:
    def __init__(self):
        self.sqs = boto3.client('sqs')
        self.ssm = boto3.client('ssm')
        
        try:
            # Get queue URLs from SSM Parameter Store
            response = self.ssm.get_parameter(
                Name='/crs-app/sqs/queue_url'
            )
            self.queue_url = response['Parameter']['Value']
            logger.info(f"Retrieved main queue URL from SSM: {self.queue_url}")
            
            response = self.ssm.get_parameter(
                Name='/crs-app/sqs/dlq_url'
            )
            self.dlq_url = response['Parameter']['Value']
            logger.info(f"Retrieved DLQ URL from SSM: {self.dlq_url}")
            
        except ClientError as e:
            logger.error(f"Error fetching SQS URLs from SSM: {str(e)}")
            raise

    def send_message(self, message_body, message_attributes=None):
        """
        Send a message to the SQS queue
        """
        try:
            message_params = {
                'QueueUrl': self.queue_url,
                'MessageBody': json.dumps(message_body)
            }
            
            if message_attributes:
                message_params['MessageAttributes'] = message_attributes
                
            response = self.sqs.send_message(**message_params)
            logger.info(f"Message sent. MessageId: {response['MessageId']}")
            return True, response['MessageId']
            
        except ClientError as e:
            logger.error(f"Error sending message to SQS: {str(e)}")
            return False, str(e)

    def receive_messages(self, max_messages=10):
        """
        Receive messages from the SQS queue
        """
        try:
            response = self.sqs.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=max_messages,
                WaitTimeSeconds=20
            )
            return response.get('Messages', [])
        except ClientError as e:
            logger.error(f"Error receiving messages from SQS: {str(e)}")
            raise

    def delete_message(self, receipt_handle):
        """
        Delete a message from the queue after processing
        """
        try:
            self.sqs.delete_message(
                QueueUrl=self.queue_url,
                ReceiptHandle=receipt_handle
            )
            return True, "Message deleted successfully"
            
        except ClientError as e:
            logger.error(f"Error deleting message from SQS: {str(e)}")
            return False, str(e)

    def process_messages(self, handler_function, max_messages=10):
        """
        Process messages using a handler function
        """
        messages = self.receive_messages(max_messages=max_messages)
        
        if not messages:
            return False, "No messages received"
            
        for message in messages:
            try:
                # Parse message body
                message_body = json.loads(message['Body'])
                
                # Process message using handler function
                handler_function(message_body)
                
                # Delete message after successful processing
                self.delete_message(message['ReceiptHandle'])
                
            except Exception as e:
                logger.error(f"Error processing message: {str(e)}")
                continue
                
        return True, f"Processed {len(messages)} messages" 