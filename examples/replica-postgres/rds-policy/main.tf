variable "user" {}

resource "aws_iam_policy" "policy_rds" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "myrdspolicy",
        "Effect" : "Allow",
        "Action" : [
          "rds-db:connect"
        ],
        "Resource" : var.user
      }
    ]
  })
  tags = {
    Humanitec = "true"
  }
}

output "arn" {
  value = aws_iam_policy.policy_rds.arn
}

// boilerplate for Humanitec terraform driver
variable "region" {}
variable "access_key" {}
variable "secret_key" {}
variable "assume_role_arn" {}


terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
  assume_role {
    role_arn = var.assume_role_arn
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
