terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.00"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
  }
}
