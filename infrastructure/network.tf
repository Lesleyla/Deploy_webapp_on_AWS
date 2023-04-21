resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "terraform_created_vpc"
  }
}

# Create the public subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  cidr_block        = var.public_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.main.id
  availability_zone = var.azs[count.index]

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Create the private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  cidr_block        = var.private_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.main.id
  availability_zone = var.azs[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "terra_created_igw"
  }
}

# Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_subnets_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Create a private route table and associate it with the private subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private_rt"
  }
}

resource "aws_route_table_association" "private_subnets_association" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}
#security group for load balancer
resource "aws_security_group" "lb_security_group" {
  name_prefix = "loadbalancer-sg-"
  description = "Security Group for Load Balancer"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Load Balancer Security Group"
  }
}

# The application security group(EC2 security group)
resource "aws_security_group" "my_app_sg" {
  name_prefix = "application_sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_security_group.id]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#DB security group
resource "aws_security_group" "db_security_group" {
  name_prefix = "db-sg-"
  description = "Security group for RDS instances"

  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.my_app_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database Security Group"
  }
}

#S3 bucket
resource "random_pet" "bucket_name" {
  length    = 2
  separator = "-"
}

resource "aws_s3_bucket" "private_bucket" {
  bucket        = "${random_pet.bucket_name.id}-private-bucket"
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "transition-to-standard-ia"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}


# Create an RDS Parameter Group
resource "aws_db_parameter_group" "postgres_param_group" {
  name_prefix = "postgres-param-group-"
  family      = "postgres14"
  description = "My custom parameter group for PostgreSQL 14"
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
}

# Create a DB Subnet Group for private subnets
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnets[0].id,
    aws_subnet.private_subnets[1].id,
    aws_subnet.private_subnets[2].id
  ]
  description = "Subnet group for RDS instances in private subnets"
}
#Retrieves the current AWS account ID
data "aws_caller_identity" "current" {}

#Add KMS for Encrypted RDS Instance
resource "aws_kms_key" "rds_encryption_key" {
  description = "Customer-managed KMS key for RDS instance encryption"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable user permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = "*"
      },
      {
        Sid    = "Add roles to allow use of the key"
        Effect = "Allow"
        Principal = {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        }
        Action   = ["kms:*"]
        Resource = "*"
      }
    ]
  })
}
# Create an RDS Instance
resource "aws_db_instance" "rds_instance" {
  identifier           = "csye6225"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.2"
  instance_class       = "db.t3.micro"
  db_name              = "csye6225"
  username             = "csye6225"
  password             = "123456abc"
  parameter_group_name = aws_db_parameter_group.postgres_param_group.name
  skip_final_snapshot  = true
  publicly_accessible  = false
  multi_az             = false
  # Attach to the private subnet group
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.id
  # Enable encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_encryption_key.arn
  tags = {
    Name = "RDS Instance"
  }
}

resource "aws_iam_policy" "WebAppS3" {
  name = "WebAppS3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_role" "ec2_csye6225" {
  name = "EC2-CSYE6225"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "webapp_s3_attachment" {
  policy_arn = aws_iam_policy.WebAppS3.arn
  role       = aws_iam_role.ec2_csye6225.name
}
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ec2_csye6225.name
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-CSYE6225-profile"
  role = aws_iam_role.ec2_csye6225.name
}
#add KMS for Encrypted EBS Volumes
resource "aws_kms_key" "ebs_encryption_key" {
  description = "Customer-managed KMS key for EBS volume encryption"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable user permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = "*"
      },
      {
        Sid    = "Add roles to allow use of the key"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
          ]
        }
        Action   = ["kms:*"]
        Resource = "*"
      }
    ]
  })
}

data "template_file" "user_data" {
  template = <<EOF
    #!/bin/bash
    sed -i "s/RDS_USERNAME:.*/RDS_USERNAME: ${aws_db_instance.rds_instance.username}/g" /var/aws/webapp/app.yml
    sed -i "s/RDS_PASSWORD:.*/RDS_PASSWORD: ${aws_db_instance.rds_instance.password}/g" /var/aws/webapp/app.yml
    sed -i "s/RDS_HOSTNAME:.*/RDS_HOSTNAME: ${aws_db_instance.rds_instance.endpoint}/g" /var/aws/webapp/app.yml
    sed -i "s/RDS_DATABASENAME:.*/RDS_DATABASENAME: ${aws_db_instance.rds_instance.db_name}/g" /var/aws/webapp/app.yml
    sed -i "s/S3_BUCKET_NAME:.*/S3_BUCKET_NAME: ${aws_s3_bucket.private_bucket.bucket}/g" /var/aws/webapp/app.yml
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/var/aws/cloudwatch-config.json
    sudo systemctl daemon-reload
    sudo systemctl enable webapp
    sudo systemctl start webapp
  EOF
}
resource "aws_launch_template" "asg_launch_template" {
  name = "asg_launch_template"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      delete_on_termination = true
      volume_type           = "gp2"
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs_encryption_key.arn
    }
  }
  disable_api_termination = true
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  image_id      = var.custom_ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.my_app_sg.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg_launch_template"
    }
  }
  user_data = base64encode(data.template_file.user_data.rendered)
}

resource "aws_autoscaling_group" "webapp_asg" {
  name = "csye6225-asg-spring2023"
  vpc_zone_identifier = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id,
    aws_subnet.public_subnets[2].id
  ]
  min_size         = 1
  max_size         = 3
  desired_capacity = 1
  launch_template {
    id      = aws_launch_template.asg_launch_template.id
    version = "$Latest"
  }
  health_check_type = "ELB"
  force_delete      = true
  default_cooldown  = 60
  tag {
    key                 = "Name"
    value               = "ec2_instance"
    propagate_at_launch = true
  }
  target_group_arns = [
    aws_lb_target_group.alb_tg.arn
  ]
}


resource "aws_autoscaling_policy" "asg_cpu_up_policy" {
  name                   = "csye6225-asg-cpu-up"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name          = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.asg_cpu_up_policy.arn]
}
resource "aws_autoscaling_policy" "asg_cpu_down_policy" {
  name                   = "csye6225-asg-cpu-down"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name          = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "3"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.asg_cpu_down_policy.arn]
}
resource "aws_lb" "lb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_security_group.id]
  subnets = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id,
    aws_subnet.public_subnets[2].id
  ]
  enable_deletion_protection = false
  tags = {
    Application = "WebApp"
  }
}
resource "aws_lb_target_group" "alb_tg" {
  name        = "csye6225-lb-alb-tg"
  port        = 8081
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = "/healthz"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
  }
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-west-2:182238019885:certificate/174af89f-cf16-4754-af2b-e272724bee23"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

## Create Route53 A record to point to the EC2 instance
resource "aws_route53_record" "web_server" {
  zone_id = var.r53_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}