output "instance_profile_name" {
  description = "Ten Instance Profile de gan vao Launch Template"
  value       = aws_iam_instance_profile.ec2.name
}
