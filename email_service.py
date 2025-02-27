import boto3
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger(__name__)

class EmailService:
    def __init__(self, region_name='us-east-1'):
        self.ses_client = boto3.client('ses', region_name=region_name)
        self.sender = "direselign@gmail.com"  # Update this

    def send_email(self, recipient, subject, body_text, body_html=None):
        try:
            message = {
                'Subject': {
                    'Data': subject
                },
                'Body': {
                    'Text': {
                        'Data': body_text
                    }
                }
            }

            if body_html:
                message['Body']['Html'] = {'Data': body_html}

            response = self.ses_client.send_email(
                Source=self.sender,
                Destination={
                    'ToAddresses': [recipient]
                },
                Message=message
            )
            logger.info(f"Email sent! Message ID: {response['MessageId']}")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'MessageRejected':
                logger.info(f"Email not sent (address not verified): {recipient}")
            else:
                logger.warning(f"Could not send email to {recipient}: {str(e)}")
            return False 