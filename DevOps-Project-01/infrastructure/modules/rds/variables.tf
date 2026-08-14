# RDS Module

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for RDS"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

# Master username khong phai secret. Mat khau do RDS tu quan ly qua
# Secrets Manager (manage_master_user_password), nen module nay khong nhan
# bien mat khau nao ca.
variable "db_username" {
  description = "Master username cua RDS"
  type        = string
}

variable "instance_class" {
  description = "Loai instance cho RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Bat Multi-AZ. Tang gap doi chi phi, chi bat khi can chung minh HA."
  type        = bool
  default     = false
}
