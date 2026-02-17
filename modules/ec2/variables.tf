variable "instance_configs" {
  description = "Map of instance configurations. Key is the instance name."
  type = map(object({
    instance_type    = string
    root_volume_size = number
    root_volume_type = string
    additional_security_rules = optional(list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    })), [])
  }))
}

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet in the VPC"
  type        = string
}
