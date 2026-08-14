output "state_bucket_name" {
  description = "Ten S3 bucket luu Terraform state - dien vao envs/*/backend.hcl"
  value       = aws_s3_bucket.tfstate.id
}

output "state_lock_table_name" {
  description = "Ten DynamoDB table dung de lock state"
  value       = aws_dynamodb_table.tfstate_lock.name
}
