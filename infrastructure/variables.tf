# Define variables
variable "region" {
  type        = string
  description = "region"
}

variable "profile" {
  type        = string
  description = "cli_profile"
}

variable "vpc_cidr" {
  type        = string
  description = "vpc_cidr"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "public_subnet_cidrs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "private_subnet_cidrs"
}

variable "azs" {
  type        = list(string)
  description = "azs"
}
variable "custom_ami_id" {
  type        = string
  description = "custom_ami_id"
}

variable "key_name" {
  type        = string
  description = "key_name"
}

variable "r53_zone_id" {
  type        = string
  description = "r53_zone_id"
}

variable "domain_name" {
  type        = string
  description = "domain_name"
}