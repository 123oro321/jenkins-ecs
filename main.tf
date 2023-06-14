# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {}
resource "aws_instance" "app_server" {
  ami           = "ami-09db9d79b41ec058e"
  instance_type = "t2.micro"

  tags = {
    Name = var.instance_name
  }
}
