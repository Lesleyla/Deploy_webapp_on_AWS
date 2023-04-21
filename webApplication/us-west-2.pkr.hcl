variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "source_ami" {
  type    = string
  default = "ami-0f1a5f5ada0e7da53" #linux2 us-est-2
}
variable "ssh_username" {
  type    = string
  default = "ec2-user"
}
variable "subnet_id" {
  type    = string
  default = "subnet-0aa188d3831158c4d" #us-west-2
}

source "amazon-ebs" "my-ami" {
  region          = "${var.aws_region}"
  ami_name        = "csye6225_${formatdate("YYYY_MM_DD_hh_mm_ss", timestamp())}"
  ami_description = "AMI for CSYE 6225 us-west-2"
  ami_regions = [
    "us-west-2",
  ]

  aws_polling {
    delay_seconds = 120
    max_attempts  = 50
  }

  instance_type = "t2.micro"
  source_ami    = "${var.source_ami}"
  ssh_username  = "${var.ssh_username}"
  subnet_id     = "${var.subnet_id}"

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp2"
  }
  ami_users = ["182238019885"]
}

build {
  sources = ["source.amazon-ebs.my-ami"]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /var/aws/webapp",
    ]
  }
  provisioner "file" {
    source      = "main.py"
    destination = "/tmp/main.py"
  }
  provisioner "file" {
    source      = "app.yml"
    destination = "/tmp/app.yml"
  }
  provisioner "file" {
    source      = "cloudwatch-config.json"
    destination = "/tmp/cloudwatch-config.json"
  }
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/main.py /var/aws/webapp/main.py",
      "sudo mv /tmp/app.yml /var/aws/webapp/app.yml",
      "sudo mv /tmp/cloudwatch-config.json /var/aws/cloudwatch-config.json"
    ]
  }
  provisioner "shell" {
    script = "setup.sh"
  }
}