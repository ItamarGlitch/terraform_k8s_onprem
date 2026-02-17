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
  description = "Allow SSH and HTTPS for EC2 instances"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "allow_all_egress" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_ingress" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow SSH inbound traffic"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_https_ingress" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow HTTPS inbound traffic"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_k8s_api_ingress" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow Kubernetes API server inbound traffic"
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_instance" "this" {
  for_each = toset(var.instance_names)

  ami                         = data.aws_ssm_parameter.ubuntu_24_ami.value
  instance_type               = "t3.xlarge"
  key_name                    = aws_key_pair.ec2.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = each.key
  }
}
