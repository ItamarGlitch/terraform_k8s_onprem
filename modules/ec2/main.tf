data "aws_ssm_parameter" "ubuntu_24_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  key_name   = "ec2-key-${replace(var.vpc_id, "vpc-", "")}"
  public_key = tls_private_key.ec2.public_key_openssh
}

resource "local_file" "ec2_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.root}/ec2-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "ec2" {
  name        = "ec2-ssh-https-${replace(var.vpc_id, "vpc-", "")}"
  description = "Allow management ports externally; all traffic internally within VPC"
  vpc_id      = var.vpc_id

  # External management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API server (kubectl)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow all intra-cluster traffic (etcd, kubelet, CNI, etc.) within the security group
resource "aws_security_group_rule" "ec2_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.ec2.id
  description              = "Allow all internal traffic between cluster nodes"
}

# Per-instance security groups for custom rules
resource "aws_security_group" "instance_custom" {
  for_each = {
    for name, config in var.instance_configs : name => config
    if length(config.additional_security_rules) > 0
  }

  name        = "ec2-custom-${each.key}-${replace(var.vpc_id, "vpc-", "")}"
  description = "Custom security rules for ${each.key}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "ec2-custom-${each.key}"
  }
}

# Custom ingress rules per instance
resource "aws_security_group_rule" "instance_custom_ingress" {
  for_each = merge([
    for instance_name, config in var.instance_configs : {
      for idx, rule in config.additional_security_rules :
      "${instance_name}-${idx}" => merge(rule, { instance_name = instance_name })
    }
  ]...)

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
  security_group_id = aws_security_group.instance_custom[each.value.instance_name].id
}

resource "aws_instance" "this" {
  for_each = var.instance_configs

  ami           = data.aws_ssm_parameter.ubuntu_24_ami.value
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.ec2.key_name
  subnet_id     = var.subnet_id

  vpc_security_group_ids = concat(
    [aws_security_group.ec2.id],
    length(each.value.additional_security_rules) > 0 ? [aws_security_group.instance_custom[each.key].id] : []
  )

  associate_public_ip_address = true

  root_block_device {
    volume_size = each.value.root_volume_size
    volume_type = each.value.root_volume_type
  }

  tags = {
    Name = each.key
  }
}
