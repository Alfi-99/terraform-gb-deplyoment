# =============================================================================
# OUTPUTS - Informasi penting setelah terraform apply
# =============================================================================

output "vpc_id" {
  description = "ID dari VPC yang dibuat"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS Name dari Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "api_gateway_url" {
  description = "URL endpoint API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "amplify_app_url" {
  description = "URL aplikasi frontend di Amplify"
  value       = "https://${var.amplify_branch_name}.${aws_amplify_app.frontend.default_domain}"
}

output "rds_endpoint" {
  description = "Endpoint RDS Database"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "Nama database RDS"
  value       = aws_db_instance.main.db_name
}

output "s3_deployment_bucket" {
  description = "Nama S3 bucket untuk deployment"
  value       = aws_s3_bucket.deployment.bucket
}

output "s3_app_bucket" {
  description = "Nama S3 bucket untuk aplikasi"
  value       = aws_s3_bucket.app_storage.bucket
}

output "dynamodb_log_table" {
  description = "Nama DynamoDB table untuk logging"
  value       = aws_dynamodb_table.app_logs.name
}

output "lambda_post_arn" {
  description = "ARN Lambda function POST"
  value       = aws_lambda_function.api_post.arn
}

output "lambda_get_arn" {
  description = "ARN Lambda function GET"
  value       = aws_lambda_function.api_get.arn
}

output "eb_blue_env_url" {
  description = "URL Elastic Beanstalk Environment BLUE"
  value       = aws_elastic_beanstalk_environment.blue.cname
}

output "eb_green_env_url" {
  description = "URL Elastic Beanstalk Environment GREEN"
  value       = aws_elastic_beanstalk_environment.green.cname
}

output "active_environment" {
  description = "Environment yang sedang aktif (blue/green)"
  value       = var.active_color
}

output "efs_id" {
  description = "ID dari EFS file system"
  value       = aws_efs_file_system.main.id
}

output "deployment_instructions" {
  description = "Petunjuk deployment Blue/Green"
  value       = <<-EOT
    ============================================================
    BLUE/GREEN DEPLOYMENT INSTRUCTIONS
    ============================================================
    Environment Aktif: ${upper(var.active_color)}
    
    Untuk switch traffic ke ${var.active_color == "blue" ? "GREEN" : "BLUE"}:
    terraform apply -var="active_color=${var.active_color == "blue" ? "green" : "blue"}"
    
    Blue URL  : ${aws_elastic_beanstalk_environment.blue.cname}
    Green URL : ${aws_elastic_beanstalk_environment.green.cname}
    ALB URL   : ${aws_lb.main.dns_name}
    API URL   : ${aws_api_gateway_stage.main.invoke_url}
    ============================================================
  EOT
}
