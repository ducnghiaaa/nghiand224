output "rds_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "master_user_secret_arn" {
  description = "ARN cua secret chua mat khau master do RDS tu quan ly"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
