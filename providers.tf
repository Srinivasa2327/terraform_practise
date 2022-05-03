terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.12.1"
    }
  }
}

provider "aws" {
    profile = "mfa"
    region = "eu-central-1"
    assume_role {
      role_arn = "arn:aws:iam::058553766627:role/Admin"
  }
}

provider "aws" {
    alias = "useast1"
    profile = "mfa"
    region = "us-east-1"
    assume_role {
      role_arn = "arn:aws:iam::058553766627:role/Admin"
  }
}
