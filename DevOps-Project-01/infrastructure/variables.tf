variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["192.168.1.0/24", "192.168.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["192.168.3.0/24", "192.168.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "javaapp"
}

variable "db_username" {
  description = "Master username cua RDS. Khong phai secret - mat khau do RDS tu quan ly qua Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "Loai instance cho RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Bat Multi-AZ cho RDS. Tang gap doi chi phi."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "health_check_path" {
  description = "Duong dan ALB kiem tra suc khoe. Doi thanh /actuator/health o Tuan 2 khi app co Actuator."
  type        = string
  default     = "/"
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "nat_mode" {
  description = "NAT mode for the VPC"
  default     = "gateway"
  type        = string
}

 