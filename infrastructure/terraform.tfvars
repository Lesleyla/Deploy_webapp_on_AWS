region               = "us-west-2"
profile              = "demo"
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
private_subnet_cidrs = ["10.20.4.0/24", "10.20.5.0/24", "10.20.6.0/24"]
azs                  = ["us-west-2a", "us-west-2b", "us-west-2c"]
custom_ami_id        = "******************"
key_name             = "******************"
r53_zone_id          = "******************"
domain_name          = "demo.mgoncloud.me"