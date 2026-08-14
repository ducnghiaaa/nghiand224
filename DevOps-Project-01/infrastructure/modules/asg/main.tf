# ASG Module

# Lay AMI Amazon Linux 2023 moi nhat thay vi ghi cung mot ID.
#
# ID cu ami-0c02fb55956c7d316 chi ton tai o us-east-1, nen o ap-southeast-1
# apply se chet vi AMI khong ton tai. AMI hardcode cung muc dan theo thoi
# gian khi AWS ngung ho tro ban cu.
#
# O Tuan 3, data source nay se doi sang loc theo tag cua AMI do Packer bake.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "${var.environment}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_group_ids

  # Khong cai gi luc khoi dong.
  #
  # user_data cu chay "yum install tomcat" nhung khong he deploy file WAR
  # nao - ung dung khong bao gio chay duoc. Va AL2023 dung dnf, khong co
  # goi tomcat trong repo.
  #
  # O Tuan 3, Packer bake san Tomcat 9 va file WAR vao AMI, nen instance
  # khoi dong len la phuc vu duoc ngay.

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web-instance"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = var.target_group_arns
  # Tam thoi dung EC2 thay vi ELB. Den Tuan 3, khi AMI da co san app va
  # endpoint /actuator/health hoat dong, se doi lai thanh ELB.
  #
  # Neu de ELB ngay bay gio: instance chua co app -> ALB danh dau unhealthy
  # -> ASG terminate va tao lai -> lap VO HAN, vua khong bao gio on dinh
  # vua dot tien lien tuc.
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}
