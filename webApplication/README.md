# webapp

This application was built using Python Flask framework.  
Prerequisites and instructions for building and deploying your application locally:  

1.get clone this repository  
2.make venv in the project directory by running `python -m venv venv` in the terminal.  
3.active your venv "in mac and linux `source venv/bin/activate`.  
4.`pip install flask flask-sqlalchemy flask-session flask-bcrypt flask-httpauth psycopg2 pytest boto3 PyYAML statsd`.  
5.run this project in the terminal: `python main.py`.  

aws AMI build commands:
1.`packer fmt us-west-2.pkr.hcl`
2.`packer validate us-west-2.pkr.hcl`
3.`packer build us-west-2.pkr.hcl`