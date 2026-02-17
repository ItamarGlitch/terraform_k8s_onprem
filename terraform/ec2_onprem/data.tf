data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "${var.account_id}-tfstate"
    region = "us-east-1"
    key    = "platform/vpc.tfstate"
  }
}
