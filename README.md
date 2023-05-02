# Deploy_webapp_on_AWS

* Demo Video:https://youtu.be/Iaz3t13Mm0E

Created a web application implemented with `RESTful APIs`, it'll automatically bootstrap the database at startup. And then I build the infrastructure on the cloud(AWS) to host the application.
* WEB APPLICATION
  Created a web application using `Flask` framework. For this project, I focused on the backend API (no UI) service. I also implemented RESTful APIs based on user stories you will find below.
  - application function
    * Create a new user
    * Update user information
    * Get user information
    * Add Product
    * Update Product
    * Delete Product
    * Users can upload images to the products they have created.
    * Users can delete only their own images from the products they have created.
    * Users should not be able to delete images uploaded by other users or from products created by other users.
  - application highlight
    * provide a `basic authentication token` when making an API call to the authenticated endpoint.
    * The application is expected to automatically bootstrap the database at startup.
    * Use `systemd` to set up `auto run`.
    * Registered a `domain` name for this application and configured Route 53 for DNS service.
    * All application log data and API usage metrics is available in CloudWatch.
    * Secured the web application endpoints with `SSL` certificates.
* AWS INFRASTRUCTURE
  - AWS Networking
    * Created Virtual Private Cloud (VPC).
    * Created 3 public subnets and 3 private subnets in my VPC, each in a different availability zone in the same region in the same VPC.
    * Created an Internet Gateway resource and attach the Internet Gateway to the VPC.
    * Created public and private route table. Attached all subnets created to the route table.
    * Created an EC2 security group for EC2 instances that will host the web application. And a DB security group for RDS instance.
    * The EC2 instance will be launched in the VPC created above by your Terraform template.
  - AWS EC2 instances
    * EC2 instances launched in the auto-scaling group are now be load balanced.
    * `Auto scaling` application and the web application will now only be accessible from the load balancer.
    * AutoScaling Policies: Scale up policy when average CPU usage is above `5%`. Increment by `1`. Scale down policy when average CPU usage is below `3%`. Decrement by `1`.
    * Created `JMeter` `load testing` scripts to test the app.
    * EBS volumes are encrypted with customer managed key.
  - AWS S3 Bucket
    * Created a `private S3 bucket` to store product pictures that users uploaded.
    * Enabled default encryption for S3 Buckets.
    * S3 credentials isn't hardcoded and the application is only able to access S3 using the IAM role attached to the EC2 instances.
  - AWS RDS instance
    * The application data used to be stored in PostgresSQL locally, but now AWS RDS replaced it and now the application data's stored on cloud.
    * `RDS` are encrypted with `customer managed key`.
  - AWS CloudWatch
    * Configure `CloudWatch Agent` to let all application log data to be available in CloudWatch.
    * Metrics on `API usage` are available in CloudWatch.
    * Count the number of times each API is called.
    * Retrieve custom metrics using `StatsD`.
  - Build `Amazon Machine Image`
    * Use Amazon Linux 2 as source image to create the custom AMI using Packer.
    * The AMI includes everything needed to run the application and the application binary itself.
* CI/CD
  - Run the application unit tests for each pull request raised.
  - Validate Packer Template.
  - After merge the pull request, the application artifact is built for copying to AMI.
  - AMI is built when PR is merged.
  - Install application dependencies (pip install for Python)
  - Set up the application by copying the application artifacts and the configuration files.
  - Configure the application to start automatically when VM is launched.
  - `Continuous Deplyment`: Create a new Launch Template version with the latest AMI ID for the autoscaling group, if there's new application version uploaded. The autoscaling group is configured to use the latest version of the Launch Template. Issued command to the auto-scale group to do an instance refresh.
