# Security Groups Module

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for application load balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# Application Security Group
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Khong co rule port 22. Truy cap may chu qua SSM Session Manager:
  # agent tren may tu ket noi RA ngoai qua NAT Gateway, khong co ket noi
  # nao di VAO tu Internet.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Database Security Group
resource "aws_security_group" "db" {
  name        = "${var.environment}-db-sg"
  description = "Security group for database"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-db-sg"
    Environment = var.environment
  }
}

# Khong co bastion host, va vi vay cung khong co security group cho no.
#
# Cau hinh truoc day khai bao mot SG bastion nhung khong he tao instance
# nao dung no - code chet. Va rule cua no mo port 22 cho 0.0.0.0/0.
#
# Thay vao do: SSM Session Manager. Instance nhan IAM instance profile co
# quyen SSM (them o Tuan 2), agent tu ket noi ra ngoai qua NAT Gateway.
# Khong can SSH key, khong mo port 22 o dau, va moi phien deu duoc ghi log. 