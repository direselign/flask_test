#!/bin/bash

# Deployment time: ${deployment_time}

# Set up logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution - $(date)"

# Update and install required packages
apt-get update && apt-get upgrade -y
apt-get install -y nginx python3-pip git python3-venv openssh-server postgresql-client libpq-dev python3-dev awscli

# Create and configure ubuntu user
useradd -m -s /bin/bash ubuntu || echo "User ubuntu already exists"
usermod -aG sudo ubuntu
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu

# Set up SSH for ubuntu user
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
echo "${ssh_public_key}" > /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Configure SSH
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Clone and set up application
cd /home/ubuntu
rm -rf /home/ubuntu/flask_test
git clone https://github.com/direselign/flask_test.git

# Fix git repository permissions
chown -R ubuntu:ubuntu /home/ubuntu/flask_test
chmod -R 775 /home/ubuntu/flask_test/.git

cd flask_test

# Create templates directory if it doesn't exist
mkdir -p templates
chmod 755 templates

# Configure git to use ubuntu user
sudo -u ubuntu git config --global user.email "ubuntu@example.com"
sudo -u ubuntu git config --global user.name "Ubuntu User"

# Verify we have the latest code
echo "Git commit hash: $(git rev-parse HEAD)"
echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Last commit message: $(git log -1 --pretty=%B)"

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Create CloudWatch log group with retention
aws logs create-log-group --log-group-name /flask-app/application --region ${aws_region}
aws logs put-retention-policy --log-group-name /flask-app/application --retention-in-days 30 --region ${aws_region}

# Verify installations
python3 -m pip freeze > installed_requirements.txt
echo "Installed packages:"
cat installed_requirements.txt

# Deactivate virtual environment
deactivate

# Configure Nginx
cat > /etc/nginx/conf.d/flask.conf <<EOL
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/flask_access.log;
    error_log /var/log/nginx/flask_error.log;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;

        # Add timeouts
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
EOL

rm /etc/nginx/sites-enabled/default

# Start Nginx
systemctl enable nginx
systemctl restart nginx

# Create systemd service for Flask app
cat > /etc/systemd/system/flask.service <<EOL
[Unit]
Description=Gunicorn instance to serve Flask application
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/flask_test
Environment="PATH=/home/ubuntu/flask_test/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONPATH=/home/ubuntu/flask_test"
Environment="AWS_DEFAULT_REGION=${aws_region}"
Environment="AWS_REGION=${aws_region}"
Type=simple
Restart=always
RestartSec=1
ExecStart=/home/ubuntu/flask_test/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 main:app \
    --log-level debug \
    --error-logfile /home/ubuntu/flask_test/gunicorn_error.log \
    --access-logfile /home/ubuntu/flask_test/gunicorn_access.log \
    --capture-output \
    --timeout 120

[Install]
WantedBy=multi-user.target
EOL

# Start Flask application
systemctl enable flask
systemctl start flask

echo "Setup completed - $(date)"