# Vpc resource naming
variable "vpc_name" {
  description = "Name of the VPC"
  type        = "string"
  default     = "ge_digital_terraform_vpc"
}

# Tags
variable "tags" {
  description = "Different tag values which should be assigned to AWS resources created via Terraform"
  type        = "map"

  default = {
    "Name"  = "Ge_digital_terraform"
    "owner" = "terraform-8k"
  }
}

# Network details (Change this only if you know what you are doing or if you think you are lucky)
variable "vpc_cidr" {
  type        = "string"
  description = "CIDR of the VPC"
  default     = "10.1.0.0/16"
}

# AWS Regions / Zones
variable "aws_region" {
  type        = "string"
  description = "AWS region which should be used"
  default     = "us-east-1"
}

variable "aws_zones" {
  type        = "list"
  description = "AWS AZs (Availability zones) where subnets should be created"
  default     = ["us-east-1a", "us-east-1b"]
}

# Private subnets
variable "private_subnets" {
  description = "Create both private and public subnets"
  type        = "string"
  default     = "false"
}

variable "ig_name" {
  description = "Name of the VPC"
  type        = "string"
  default     = "ge_digital_terraform_ig"
}

variable "cloudwatch_group_name" {}
variable "vpc_flowlog_arn" {}
