locals {
  common_tags = {
    # "Owner"       = "gal.r@elsight.com"
    # "Environment" = local.environment
    # "Project"     = "infra"
    # "ManagedBy"   = "Terraform"
    # "Component"   = "iam-github-oidc"
    # "GitRepo"     = "github.com/elsight/devops-aws-infra"
    # "RemoteState" = "configuration/${local.environment}/iam-github-oidc.tfstate"
  }
  vpc_id    = var.vpc_id != null ? var.vpc_id : tolist(data.aws_vpcs.available.ids)[0]
  subnet_id = var.subnet_id != null ? var.subnet_id : tolist(data.aws_subnets.selected.ids)[0]
}
