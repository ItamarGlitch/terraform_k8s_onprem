locals {
  common_tags = {
    "Owner"       = "gal.r@elsight.com"
    "Environment" = var.environment
    "Project"     = "infra-ec2-onprem"
    "ManagedBy"   = "Terraform"
    "Component"   = "ec2_onprem"
    "GitRepo"     = "github.com/elsight/terraform_k8s_onprem"
    "RemoteState" = "services/${var.environment}/terraform_k8s_onprem/ec2_onprem.tfstate"
  }
  region    = "us-east-1"
  vpc_id    = data.terraform_remote_state.vpc.outputs.vpc_id[local.region]
  subnet_id  = data.terraform_remote_state.vpc.outputs.public_subnet_ids[local.region][0]
}
