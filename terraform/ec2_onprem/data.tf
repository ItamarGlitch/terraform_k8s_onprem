data "aws_vpcs" "available" {
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}
