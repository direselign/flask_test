# List all parameters under /flask-app/
aws ssm get-parameters-by-path --path "/flask-app/" --region us-east-1

# Get a specific parameter (non-secure)
aws ssm get-parameter --name "/flask-app/db/host" --region us-east-1

# Get a secure parameter
aws ssm get-parameter --name "/flask-app/db/password" --with-decryption --region us-east-1


# For non-sensitive data
aws ssm put-parameter --name "/flask-app/db/host" --value "database-1.ccx0yswy291e.us-east-1.rds.amazonaws.com" --type "String"  --region us-east-1
# For sensitive data
aws ssm put-parameter --name "/flask-app/db/password" --value "mypostgrespassword123" --type "SecureString"  --region us-east-1
aws ssm put-parameter --name "/flask-app/db/username" --value "postgres" --type "String"  --region us-east-1
aws ssm put-parameter --name "/flask-app/db/port" --value "5432" --type "String"  --region us-east-1
aws ssm put-parameter --name "/flask-app/db/db_name" --value "flaskapp" --type "String"  --region us-east-1
aws ssm put-parameter --name "/flask-app/flask_secret_key" --value "your-secret-key" --type "SecureString"  --region us-east-1

database-1.ccx0yswy291e.us-east-1.rds.amazonaws.com



SES
# Verify an email address
aws ses verify-email-identity --email-address direselign@gmail.com --region us-east-1

# Send a test email
aws ses send-email --from-email ledirese@gmail.com --destination file://destination.json --region us-east-1

# Create a configuration set
aws ses create-configuration-set --configuration-set-name "MyConfigurationSet" --region us-east-1


aws ses get-identity-verification-attributes --identities ledirese@gmail.com

aws ses send-email --from "direselign@gmail.com" --destination "ToAddresses=['ledirese@gmail.com']" --message "Subject={Data='Test Email'},Body={Text={Data='Hello, this is a test email!'}}"



sudo systemctl restart flask
sudo systemctl status flask


from app import app, db
with app.app_context():
    db.drop_all()  # This will delete all data!
    db.create_all()