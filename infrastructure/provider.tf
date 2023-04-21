# Configure the AWS Provider
provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "random" {
  # Configuration options
}