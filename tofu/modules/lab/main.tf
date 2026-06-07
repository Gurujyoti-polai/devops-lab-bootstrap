# ─── NETWORKING ───────────────────────────────────────────────────────────────

# Fetch your current public IP dynamically — so the SG allows only YOUR machine
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  # Strip the newline from the IP response and add /32 (single IP CIDR)
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# The VPC — your private network boundary in AWS
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "devops-lab-vpc-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# Public subnet — instances here can get public IPs and reach the internet
# checkov:skip=CKV_AWS_130: intentional — public subnet needs public IPs for lab SSH access
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "devops-lab-public-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# Private subnet — no public IPs, no direct internet access
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name      = "devops-lab-private-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# Internet Gateway — the door between your VPC and the public internet
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name      = "devops-lab-igw-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# Elastic IP for the NAT Gateway — a static public IP that won't change
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name      = "devops-lab-nat-eip-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# NAT Gateway — lets private subnet instances reach the internet outbound
# Lives in the PUBLIC subnet but serves the PRIVATE subnet
resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name      = "devops-lab-nat-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }

  depends_on = [aws_internet_gateway.lab]
}

# Public route table — sends all internet traffic through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name      = "devops-lab-public-rt-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table — sends internet traffic through NAT GW (not IGW)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }

  tags = {
    Name      = "devops-lab-private-rt-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ─── SECURITY GROUP ───────────────────────────────────────────────────────────

resource "aws_security_group" "lab_ec2" {
  name        = "devops-lab-ec2-sg-${var.phase_name}"
  description = "Lab EC2 security group — SSH from your IP + extra ports"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  dynamic "ingress" {
    for_each = var.extra_ports
    content {
      description = "Extra port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # checkov:skip=CKV_AWS_382: intentional — lab instances need unrestricted outbound for package installs
  egress {
    description = "Allow all outbound - needed for package installs and AWS API calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "devops-lab-ec2-sg-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# ─── IAM ROLE FOR EC2 ─────────────────────────────────────────────────────────
# Attach an IAM role so the EC2 instance can call AWS APIs without stored credentials
# This is the correct pattern — never put access keys on an EC2 instance

resource "aws_iam_role" "lab_ec2" {
  name = "devops-lab-ec2-role-${var.phase_name}"

  # Trust policy — allows EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "devops-lab-ec2-role-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

# Attach SSM policy — lets you connect via Session Manager without SSH if needed
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.lab_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — the wrapper that attaches an IAM role to an EC2 instance
resource "aws_iam_instance_profile" "lab_ec2" {
  name = "devops-lab-ec2-profile-${var.phase_name}"
  role = aws_iam_role.lab_ec2.name
}

# ─── EC2 ──────────────────────────────────────────────────────────────────────

# Always fetch the latest Amazon Linux 2023 AMI — never hardcode AMI IDs
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "lab" {
  key_name   = "devops-lab-key-${var.phase_name}"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name      = "devops-lab-key-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}

resource "aws_instance" "lab" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.lab_ec2.id]
  key_name               = aws_key_pair.lab.key_name
  iam_instance_profile   = aws_iam_instance_profile.lab_ec2.name  # fixes CKV2_AWS_41

  # Enable detailed monitoring — fixes CKV_AWS_126
  monitoring = true

  # Encrypt the root EBS volume — fixes CKV_AWS_8
  root_block_device {
    encrypted = true
  }

  # checkov:skip=CKV_AWS_135: t3.micro does not support EBS optimized - enabled by default on this type

  # Enforce IMDSv2 - disables the unauthenticated v1 endpoint (fixes CKV_AWS_79)
  # Prevents SSRF attacks from stealing IAM credentials via 169.254.169.254
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name      = "devops-lab-ec2-${var.phase_name}"
    Project   = "devops-lab"
    Phase     = var.phase_name
    ManagedBy = "opentofu"
  }
}
