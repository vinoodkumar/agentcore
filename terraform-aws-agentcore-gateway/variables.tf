variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS service"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "container_image" {
  description = "Docker container image for the agent gateway"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units for the ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "memory" {
  description = "Memory for the ECS task in MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 30720
    error_message = "Memory must be between 512 and 30720 MB"
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "Desired count must be at least 1"
  }
}

variable "enable_autoscaling" {
  description = "Enable ECS service autoscaling"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 10
}

variable "autoscaling_target_cpu" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 75

  validation {
    condition     = var.autoscaling_target_cpu > 0 && var.autoscaling_target_cpu <= 100
    error_message = "Target CPU must be between 1 and 100"
  }
}

variable "autoscaling_target_memory" {
  description = "Target memory utilization percentage for autoscaling"
  type        = number
  default     = 75

  validation {
    condition     = var.autoscaling_target_memory > 0 && var.autoscaling_target_memory <= 100
    error_message = "Target memory must be between 1 and 100"
  }
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP status codes to use when checking for a successful response"
  type        = string
  default     = "200-299"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "microsoft_oauth_client_id" {
  description = "Microsoft OAuth client ID"
  type        = string
}

variable "microsoft_oauth_tenant_id" {
  description = "Microsoft OAuth tenant ID"
  type        = string
}

variable "microsoft_oauth_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing Microsoft OAuth client secret"
  type        = string
}

variable "kms_key_description" {
  description = "Description for the KMS key"
  type        = string
  default     = "KMS key for AgentCore Gateway encryption"
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days"
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value"
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "workload_identity_role_arn" {
  description = "ARN of IAM role for workload identity (optional)"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "ARN of OIDC provider for workload identity (optional, future-ready)"
  type        = string
  default     = ""
}

variable "host_based_routing_hosts" {
  description = "List of hostnames for host-based routing (optional)"
  type        = list(string)
  default     = []
}

variable "deregistration_delay" {
  description = "Time in seconds for ALB to wait before deregistering a target"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for the ALB"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

variable "additional_container_environment_variables" {
  description = "Additional environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
