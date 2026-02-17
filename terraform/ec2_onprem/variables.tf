variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, stage, prod)"
  type        = string
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

variable "instance_configs" {
  description = "Map of instance configurations. Key is the instance name."
  type = map(object({
    instance_type    = optional(string, "t3.medium")
    volume = optional(object({
      size = optional(number, 50)
      type = optional(string, "gp3")
    }), {})
    additional_security_rules = optional(list(object({
      type        = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    })), [])
  }))
}
