import boto3
import json
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

class SQSService:
    def __init__(self, queue_url=None, region_name='us-east-1'):
        self.sqs = boto3.client('sqs', region_name=region_name)
        self.queue_url = queue_url
        
        if not queue_url:
            try:
                # Try to get queue URL if not provided
                response = self.sqs.get_queue_url(QueueName='flask-app-queue')
                self.queue_url = response['QueueUrl']
            except ClientError as e:
                logger.error(f"Error getting queue URL: {str(e)}")
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

    def receive_messages(self, max_messages=1, wait_time=0):
        """
        Receive messages from the SQS queue
        """
        try:
            response = self.sqs.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=max_messages,
                WaitTimeSeconds=wait_time,
                AttributeNames=['All'],
                MessageAttributeNames=['All']
            )
            
            messages = response.get('Messages', [])
            return True, messages
            
        except ClientError as e:
            logger.error(f"Error receiving messages from SQS: {str(e)}")
            return False, str(e)

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
        success, messages = self.receive_messages(max_messages=max_messages)
        
        if not success:
            return False, f"Error receiving messages: {messages}"
            
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