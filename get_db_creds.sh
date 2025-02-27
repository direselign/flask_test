#!/bin/bash

# Set your AWS region
AWS_REGION="us-east-1"

# Fetch parameters from SSM
DB_USERNAME=$(aws ssm get-parameter --name "/flask-app/db/username" --region $AWS_REGION --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/flask-app/db/password" --region $AWS_REGION --with-decryption --query "Parameter.Value" --output text)
DB_HOST=$(aws ssm get-parameter --name "/flask-app/db/host" --region $AWS_REGION --query "Parameter.Value" --output text)
DB_PORT=$(aws ssm get-parameter --name "/flask-app/db/port" --region $AWS_REGION --query "Parameter.Value" --output text)
DB_NAME=$(aws ssm get-parameter --name "/flask-app/db/name" --region $AWS_REGION --query "Parameter.Value" --output text)
FLASK_SECRET_KEY=$(aws ssm get-parameter --name "/flask-app/secret-key" --region $AWS_REGION --with-decryption --query "Parameter.Value" --output text)

# Create or update .env file
cat > .env <<EOL
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
FLASK_SECRET_KEY=$FLASK_SECRET_KEY
EOL

# Set proper permissions
chmod 600 .env

echo "Database credentials have been fetched and saved to .env" 