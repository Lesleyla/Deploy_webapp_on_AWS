# aws-infra

**Build Terraform:**
cd to this directory and
use:
```
terraform init
terraform plan
terraform apply -var-file=terraform.tfvars
terraform destroy -var-file=terraform.tfvars
```
to create multiple VPCs (and resources) without any conflicts in the same AWS account & same region,
and to create other VPCs (and resources) without any conflicts in different AWS regions, create multiple .tfvars file for different vpc.
**Command to Import SSL Certificate:**

```
aws acm import-certificate --certificate fileb://demo_mgoncloud_me.crt --certificate-chain fileb://demo_mgoncloud_me.ca-bundle --private-key fileb://private.key
```