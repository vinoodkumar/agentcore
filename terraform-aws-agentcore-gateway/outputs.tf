output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.this.name
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.this.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "ecs_service_security_group_id" {
  description = "Security group ID of the ECS service"
  value       = aws_security_group.ecs_service.id
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "ecs_task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.this.family
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task_role.name
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.this.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.this.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.this.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "runtime_endpoint_url" {
  description = "Runtime endpoint URL (HTTPS)"
  value       = "https://${aws_lb.this.dns_name}"
}
