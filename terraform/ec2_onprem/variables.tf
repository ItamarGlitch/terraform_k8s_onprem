variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, stage, prod)"
  type        = string
}

variable "instance_names" {
  description = "Unique names for each EC2 instance. Add or remove names to scale instances."
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the existing VPC. Omit to use the default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "ID of the subnet in the VPC. Omit to use the first subnet in the VPC."
  type        = string
  default     = null
}
