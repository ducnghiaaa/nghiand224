# ALB Module

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID cua security group cho ALB, do module security cung cap"
  type        = string
}

variable "health_check_path" {
  description = "Duong dan ALB dung de kiem tra suc khoe target"
  type        = string
  default     = "/"
}
