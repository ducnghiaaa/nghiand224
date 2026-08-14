# Cau hinh moi truong dev.
# File nay DUOC commit - khong bao gio dat secret vao day.

aws_region  = "ap-southeast-1"
environment = "dev"

vpc_cidr           = "192.168.0.0/16"
public_subnets     = ["192.168.1.0/24", "192.168.2.0/24"]
private_subnets    = ["192.168.3.0/24", "192.168.4.0/24"]
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

instance_type        = "t3.micro"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

# Khop voi chuoi ket noi ma code Java thuc su dung.
db_name           = "UserDB"
db_username       = "dbadmin"
db_instance_class = "db.t3.micro"
db_multi_az       = false

# Doi thanh /actuator/health o Tuan 2, sau khi app co Spring Boot Actuator.
health_check_path = "/"

# Khong co db_password: RDS tu sinh va tu xoay vong mat khau master trong
# Secrets Manager. Khong co key_name: khong con SSH.
#
# nat_mode se them o Task 10.
