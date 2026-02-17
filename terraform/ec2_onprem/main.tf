terraform {
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

module "ec2" {
  source = "./modules/ec2"

  instance_names = var.instance_names
  vpc_id         = local.vpc_id
  subnet_id      = local.subnet_id
}
