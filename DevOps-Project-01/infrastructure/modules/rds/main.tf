# RDS Module

resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.environment}-database"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class
  multi_az       = var.multi_az

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # RDS tu sinh mat khau, luu vao Secrets Manager va tu xoay vong.
  # Nho vay khong co mat khau nao trong tfvars, trong state, hay trong repo.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.environment}-db-final-snapshot"

  deletion_protection = false

  tags = {
    Name        = "${var.environment}-database"
    Environment = var.environment
  }
}
