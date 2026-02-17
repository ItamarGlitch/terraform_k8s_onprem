terraform {
  backend "s3" {
    bucket = "930579047961-tfstate"
    region = "us-east-1"
    key    = "services/dev/ec2.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

provider "aws" {
  region = var.aws_region
}

data "aws_vpcs" "available" {
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  vpc_id = var.vpc_id != null ? var.vpc_id : tolist(data.aws_vpcs.available.ids)[0]
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  subnet_id = var.subnet_id != null ? var.subnet_id : tolist(data.aws_subnets.selected.ids)[0]
}

module "ec2" {
  source = "./modules/ec2"

  instance_configs = var.instance_configs
  vpc_id           = local.vpc_id
  subnet_id        = local.subnet_id
}
