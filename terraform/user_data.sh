#!/bin/bash

# Set up logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution - $(date)"

# Update and install required packages
apt-get update && apt-get upgrade -y
apt-get install -y nginx python3-pip git python3-venv openssh-server

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
git clone https://github.com/direselign/flask_test.git
chown -R ubuntu:ubuntu /home/ubuntu/flask_test
cd flask_test

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Deactivate virtual environment
deactivate

# Configure Nginx
cat > /etc/nginx/conf.d/flask.conf <<EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
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
Environment="PATH=/home/ubuntu/flask_test/venv/bin"
ExecStart=/home/ubuntu/flask_test/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 app:app

[Install]
WantedBy=multi-user.target
EOL

# Start Flask application
systemctl enable flask
systemctl start flask

echo "Setup completed - $(date)"