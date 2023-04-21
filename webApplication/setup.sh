#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras install epel -y
sudo yum install git -y
sudo yum install gcc -y
sudo yum install python3-pip python3-devel python3-setuptools -y
sudo amazon-linux-extras install postgresql14 -y
sudo yum install postgresql-devel -y

# sudo postgresql-setup initdb
# sudo systemctl enable postgresql
# sudo systemctl start postgresql

# echo "CREATE USER csye6225 WITH PASSWORD '123456';" | sudo -u postgres psql
# echo "CREATE DATABASE cloudwebapp OWNER csye6225;" | sudo -u postgres psql
# echo "GRANT ALL PRIVILEGES ON DATABASE cloudwebapp TO csye6225;" | sudo -u postgres psql

sudo chown -R ec2-user:ec2-user /var/aws/webapp
sudo chmod -R 755 /var/aws/webapp


cd /var/aws/webapp

python3 -m venv venv
source venv/bin/activate
pip3 install flask flask-sqlalchemy flask-session flask-bcrypt flask-httpauth psycopg2 pytest boto3 PyYAML statsd

# sudo sed -i 's/peer/trust/g' /var/lib/pgsql/data/pg_hba.conf
# sudo sed -i 's/ident/trust/g' /var/lib/pgsql/data/pg_hba.conf
# sudo sed -i "s/host *all *all *127.0.0.1\/32 *ident/host all csye6225 0.0.0.0\/0 md5/g" /var/lib/pgsql/data/pg_hba.conf
# sudo systemctl restart postgresql
sudo yum install amazon-cloudwatch-agent -y

sudo touch /etc/systemd/system/webapp.service
sudo chown ec2-user:ec2-user /etc/systemd/system/webapp.service
sudo chmod u+w /etc/systemd/system/webapp.service
cat > /etc/systemd/system/webapp.service <<EOF
[Unit]
Description=Gunicorn instance to serve webapp
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/var/aws/webapp
ExecStart=/var/aws/webapp/venv/bin/python3 /var/aws/webapp/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable webapp
sudo systemctl start webapp