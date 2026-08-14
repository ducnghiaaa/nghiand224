output "alb_dns_name" {
  description = "DNS name cua ALB - mo trinh duyet vao dia chi nay de xem app"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint cua RDS (host:port)"
  value       = module.rds.rds_instance_endpoint
}

output "asg_name" {
  description = "Ten Auto Scaling Group - dung cho lenh start-instance-refresh"
  value       = module.asg.asg_name
}

output "vpc_id" {
  description = "ID cua VPC"
  value       = module.vpc.vpc_id
}
