# VPC Module

# AMI cho NAT instance (t4g.nano = kien truc ARM/Graviton, khac x86_64 cua EC2 app)
data "aws_ami" "nat_instance" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name        = "${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  # Doi so "vpc" da bi go bo o AWS provider 5.x. Phai dung "domain".
  domain = "vpc"
  count  = var.nat_mode == "gateway" ? 1 : 0

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
  }
}

# MOT NAT Gateway dung chung cho moi private subnet.
#
# Cau hinh truoc day tao mot cai moi public subnet, tuc gap doi chi phi.
# Voi moi truong dev thi mot cai la du. Danh doi da biet: neu AZ chua no
# gap su co thi private subnet o CA HAI AZ deu mat duong ra Internet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  count         = var.nat_mode == "gateway" ? 1 : 0

  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Security group cho NAT instance. Khong dung count vi security group khong ton phi.
resource "aws_security_group" "nat_instance" {
  name   = "${var.environment}-nat-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-nat-instance-sg"
    Environment = var.environment
  }
}

# NAT instance thay the cho NAT Gateway khi nat_mode = "instance". Re hon ~7 lan
# nhung la single point of failure va phai tu quan ly OS.
resource "aws_instance" "nat" {
  count                  = var.nat_mode == "instance" ? 1 : 0
  ami                    = data.aws_ami.nat_instance.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]

  # Bat buoc tat: EC2 mac dinh drop packet khong phai gui/nhan cho chinh no,
  # nhung NAT thi viec chinh la forward ho may khac.
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  EOF

  tags = {
    Name        = "${var.environment}-nat-instance"
    Environment = var.environment
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    nat_gateway_id       = var.nat_mode == "gateway" ? aws_nat_gateway.main[0].id : null
    network_interface_id = var.nat_mode == "instance" ? aws_instance.nat[0].primary_network_interface_id : null
  }

  tags = {
    Name        = "${var.environment}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.environment}-flow-logs"
  retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  name = "${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  name = "${var.environment}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
} 