# AWS AgentCore Gateway Module - Complete Usage Guide

## 📖 Table of Contents

1. [Overview](#overview)
2. [Module Components](#module-components)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
6. [Variable Reference](#variable-reference)
7. [Output Reference](#output-reference)
8. [Usage Examples](#usage-examples)
9. [Common Scenarios](#common-scenarios)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

This Terraform module creates a production-ready AWS AgentCore Gateway infrastructure with the following components:

- **Runtime Endpoint**: Application Load Balancer with HTTPS
- **VPC Configuration**: Public and private subnet separation
- **Memory & Compute**: ECS Fargate with configurable resources
- **Agent Gateway**: Complete ECS service setup
- **Agent Gateway Target**: ALB target group with health checks
- **IAM Roles & Policies**: Least privilege access
- **KMS Key**: Encryption with automatic rotation
- **OAuth2 Credential Provider**: Microsoft OAuth integration
- **Workload Identity**: IAM role assumption support

---

## Module Components

This module creates the following AWS resources:

### Network & Load Balancing
- ✅ **Application Load Balancer** (ALB) in public subnets
- ✅ **Target Group** for ECS service
- ✅ **HTTPS Listener** (port 443) with TLS 1.3
- ✅ **Security Groups** (separate for ALB and ECS)

### Compute
- ✅ **ECS Cluster** with Container Insights
- ✅ **ECS Task Definition** for Fargate
- ✅ **ECS Service** in private subnets
- ✅ **Auto Scaling** (optional) - CPU and memory-based

### Security & Access
- ✅ **IAM Task Execution Role** (for pulling images/secrets)
- ✅ **IAM Task Role** (for application permissions)
- ✅ **KMS Key** with automatic rotation
- ✅ **Security Groups** with least privilege

### Logging & Monitoring
- ✅ **CloudWatch Log Group** with KMS encryption
- ✅ **Container Insights** (optional)
- ✅ **Health Checks** (ALB and container level)

### OAuth Integration
- ✅ **Microsoft OAuth** environment variables
- ✅ **Secrets Manager** integration for client secret

---

## Prerequisites

### 1. AWS Account Setup

You must have the following already created in AWS:

#### Required AWS Resources:
```
✓ VPC with public and private subnets
✓ SSL/TLS Certificate in AWS Certificate Manager (ACM)
✓ Microsoft OAuth client secret in AWS Secrets Manager
✓ Container image in Amazon ECR or public registry
```

#### AWS CLI Configuration:
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region name: us-east-1 (or your preferred region)
```

#### Required AWS Permissions:
Your AWS credentials must have permissions to create:
- VPC resources (if creating VPC)
- ECS resources (cluster, service, task definition)
- ALB resources (load balancer, target group, listener)
- IAM resources (roles, policies)
- KMS keys
- CloudWatch log groups
- EC2 security groups

### 2. Terraform Setup

```bash
# Install Terraform (>= 1.5)
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Verify installation
terraform version
# Should show: Terraform v1.5.0 or higher
```

### 3. VPC Setup

If you don't have a VPC, create one first:

```hcl
# Create VPC (separate from this module)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "agentcore-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = "production"
  }
}
```

### 4. SSL Certificate Setup

Create or import a certificate in AWS Certificate Manager:

```bash
# Option 1: Request a certificate
aws acm request-certificate \
  --domain-name "api.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1

# Option 2: Import existing certificate
aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://certificate-chain.pem \
  --region us-east-1
```

### 5. Microsoft OAuth Setup

#### Step 1: Register Application in Azure AD

1. Go to https://portal.azure.com
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Fill in:
   - Name: `AgentCore Gateway`
   - Supported account types: Select appropriate option
   - Redirect URI: `https://your-alb-domain/oauth/callback`
5. Click **Register**
6. Note down:
   - **Application (client) ID**
   - **Directory (tenant) ID**

#### Step 2: Create Client Secret

1. In your app registration, go to **Certificates & secrets**
2. Click **New client secret**
3. Add description: `AgentCore Gateway Secret`
4. Select expiration period
5. Click **Add**
6. **IMPORTANT**: Copy the secret value immediately (you won't see it again)

#### Step 3: Store Secret in AWS Secrets Manager

```bash
# Create secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name agentcore-oauth-secret \
  --description "Microsoft OAuth client secret for AgentCore Gateway" \
  --secret-string "YOUR_CLIENT_SECRET_HERE" \
  --region us-east-1

# Note the ARN output, you'll need it for the module
# Example: arn:aws:secretsmanager:us-east-1:123456789012:secret:agentcore-oauth-secret-AbCdEf
```

### 6. Container Image Setup

Build and push your container image to Amazon ECR:

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name agentcore-gateway \
  --region us-east-1

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and tag your image
docker build -t agentcore-gateway:v1.0.0 .
docker tag agentcore-gateway:v1.0.0 \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0

# Push to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0
```

---

## Quick Start

### 1. Create Your Terraform Configuration

Create a new directory and file:

```bash
mkdir agentcore-infrastructure
cd agentcore-infrastructure
touch main.tf
```

### 2. Add Module Configuration

Edit `main.tf`:

```hcl
# Configure AWS Provider
provider "aws" {
  region = "us-east-1"  # Change to your region
}

# Use the AgentCore Gateway Module
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"  # Path to the module

  # Basic Configuration
  name        = "agentcore"
  environment = "production"

  # Network Configuration (REQUIRED)
  vpc_id = "vpc-0123456789abcdef0"  # Your VPC ID
  private_subnet_ids = [
    "subnet-0123456789abcdef0",     # Your private subnet 1
    "subnet-0123456789abcdef1",     # Your private subnet 2
  ]
  public_subnet_ids = [
    "subnet-abcdef0123456789a",     # Your public subnet 1
    "subnet-abcdef0123456789b",     # Your public subnet 2
  ]

  # Container Configuration (REQUIRED)
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0"
  container_port  = 8080

  # SSL Certificate (REQUIRED)
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  # Microsoft OAuth Configuration (REQUIRED)
  microsoft_oauth_client_id  = "12345678-1234-1234-1234-123456789012"  # From Azure AD
  microsoft_oauth_tenant_id  = "87654321-4321-4321-4321-210987654321"  # From Azure AD
  microsoft_oauth_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:agentcore-oauth-secret-AbCdEf"

  # Tags
  tags = {
    Project     = "AgentCore"
    Owner       = "Platform Team"
    Environment = "Production"
  }
}

# Output the runtime endpoint URL
output "runtime_endpoint_url" {
  description = "The HTTPS endpoint for the AgentCore Gateway"
  value       = module.agentcore_gateway.runtime_endpoint_url
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.agentcore_gateway.alb_dns_name
}
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
# Type 'yes' when prompted
```

### 4. Get the Endpoint URL

After successful deployment:

```bash
terraform output runtime_endpoint_url
# Output: https://agentcore-production-alb-1234567890.us-east-1.elb.amazonaws.com
```

---

## Step-by-Step Setup Guide

### Step 1: Gather Required Information

Create a checklist and fill in your values:

```
VPC Information:
  VPC ID: vpc-_______________
  Private Subnet 1: subnet-_______________
  Private Subnet 2: subnet-_______________
  Public Subnet 1: subnet-_______________
  Public Subnet 2: subnet-_______________

Container:
  ECR Image URI: _______________.dkr.ecr.region.amazonaws.com/image:tag
  Container Port: _____ (default: 8080)

SSL Certificate:
  ACM Certificate ARN: arn:aws:acm:region:account:certificate/_______________

Microsoft OAuth:
  Client ID: _______________
  Tenant ID: _______________
  Secret ARN: arn:aws:secretsmanager:region:account:secret:_______________

Compute Resources:
  CPU: _____ (256, 512, 1024, 2048, or 4096)
  Memory: _____ MB (512-30720)
  Desired Task Count: _____ (minimum 1)
```

### Step 2: Create Project Structure

```bash
# Create project directory
mkdir -p ~/projects/agentcore-infrastructure
cd ~/projects/agentcore-infrastructure

# Copy the module
cp -r path/to/terraform-aws-agentcore-gateway .

# Create main configuration file
touch main.tf
touch variables.tf  # Optional: for parameterization
touch terraform.tfvars  # For variable values
```

### Step 3: Configure Variables (Recommended Approach)

**Create `variables.tf`:**

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "container_image" {
  description = "Container image URI"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
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
  description = "Microsoft OAuth secret ARN"
  type        = string
}
```

**Create `terraform.tfvars`:**

```hcl
aws_region = "us-east-1"

vpc_id = "vpc-0123456789abcdef0"

private_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1"
]

public_subnet_ids = [
  "subnet-abcdef0123456789a",
  "subnet-abcdef0123456789b"
]

container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0"

certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

microsoft_oauth_client_id = "12345678-1234-1234-1234-123456789012"

microsoft_oauth_tenant_id = "87654321-4321-4321-4321-210987654321"

microsoft_oauth_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:agentcore-oauth-secret-AbCdEf"
```

**Update `main.tf`:**

```hcl
provider "aws" {
  region = var.aws_region
}

module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore"
  environment = "production"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids

  container_image = var.container_image
  certificate_arn = var.certificate_arn

  microsoft_oauth_client_id  = var.microsoft_oauth_client_id
  microsoft_oauth_tenant_id  = var.microsoft_oauth_tenant_id
  microsoft_oauth_secret_arn = var.microsoft_oauth_secret_arn

  tags = {
    Project = "AgentCore"
  }
}

output "runtime_endpoint_url" {
  value = module.agentcore_gateway.runtime_endpoint_url
}
```

### Step 4: Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Initializing provider plugins...
# Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```bash
# Validate syntax and configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### Step 6: Plan Deployment

```bash
# Generate execution plan
terraform plan -out=plan.tfplan

# Review the output carefully
# Should show approximately 18-20 resources to be created
```

### Step 7: Apply Configuration

```bash
# Apply the plan
terraform apply plan.tfplan

# Or apply directly (will prompt for confirmation)
terraform apply

# Type 'yes' when prompted
```

### Step 8: Verify Deployment

```bash
# Get outputs
terraform output

# Test the endpoint
curl -k https://$(terraform output -raw alb_dns_name)/health

# View ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --region us-east-1
```

---

## Variable Reference

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `name` | string | Name prefix for all resources | `"agentcore"` |
| `environment` | string | Environment name | `"production"` |
| `vpc_id` | string | VPC ID where resources will be created | `"vpc-0123456789abcdef0"` |
| `private_subnet_ids` | list(string) | Private subnet IDs for ECS service | `["subnet-xxx", "subnet-yyy"]` |
| `public_subnet_ids` | list(string) | Public subnet IDs for ALB | `["subnet-aaa", "subnet-bbb"]` |
| `container_image` | string | Docker container image URI | `"123456789012.dkr.ecr.us-east-1.amazonaws.com/app:v1.0.0"` |
| `certificate_arn` | string | ACM certificate ARN for HTTPS | `"arn:aws:acm:us-east-1:123456789012:certificate/xxx"` |
| `microsoft_oauth_client_id` | string | Microsoft OAuth client ID | `"12345678-1234-1234-1234-123456789012"` |
| `microsoft_oauth_tenant_id` | string | Microsoft OAuth tenant ID | `"87654321-4321-4321-4321-210987654321"` |
| `microsoft_oauth_secret_arn` | string | Secret ARN containing OAuth client secret | `"arn:aws:secretsmanager:us-east-1:123456789012:secret:xxx"` |

### Optional Variables (with defaults)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `container_port` | number | `8080` | Port on which the container listens |
| `cpu` | number | `1024` | CPU units (256, 512, 1024, 2048, 4096) |
| `memory` | number | `2048` | Memory in MB (512-30720) |
| `desired_count` | number | `2` | Number of ECS tasks |
| `enable_autoscaling` | bool | `false` | Enable ECS service autoscaling |
| `autoscaling_min_capacity` | number | `2` | Minimum tasks for autoscaling |
| `autoscaling_max_capacity` | number | `10` | Maximum tasks for autoscaling |
| `autoscaling_target_cpu` | number | `75` | Target CPU % for autoscaling |
| `autoscaling_target_memory` | number | `75` | Target memory % for autoscaling |
| `health_check_path` | string | `"/health"` | Health check endpoint path |
| `health_check_interval` | number | `30` | Health check interval in seconds |
| `health_check_timeout` | number | `5` | Health check timeout in seconds |
| `health_check_healthy_threshold` | number | `2` | Consecutive successes required |
| `health_check_unhealthy_threshold` | number | `3` | Consecutive failures required |
| `health_check_matcher` | string | `"200-299"` | HTTP status codes for success |
| `alb_ingress_cidr_blocks` | list(string) | `["0.0.0.0/0"]` | CIDR blocks allowed to access ALB |
| `kms_key_description` | string | `"KMS key for AgentCore Gateway encryption"` | KMS key description |
| `kms_key_deletion_window` | number | `30` | KMS key deletion window (7-30 days) |
| `log_retention_days` | number | `30` | CloudWatch log retention in days |
| `enable_container_insights` | bool | `true` | Enable CloudWatch Container Insights |
| `workload_identity_role_arn` | string | `""` | IAM role ARN for workload identity |
| `oidc_provider_arn` | string | `""` | OIDC provider ARN (future-ready) |
| `host_based_routing_hosts` | list(string) | `[]` | Hostnames for host-based routing |
| `deregistration_delay` | number | `30` | ALB deregistration delay in seconds |
| `enable_deletion_protection` | bool | `true` | Enable ALB deletion protection |
| `enable_cross_zone_load_balancing` | bool | `true` | Enable cross-zone load balancing |
| `idle_timeout` | number | `60` | ALB idle timeout in seconds |
| `additional_container_environment_variables` | map(string) | `{}` | Additional environment variables |
| `tags` | map(string) | `{}` | Tags to apply to all resources |

---

## Output Reference

After deployment, the module provides these outputs:

### Load Balancer Outputs
- `alb_dns_name` - DNS name of the ALB (use this to create DNS records)
- `alb_arn` - ARN of the ALB
- `alb_zone_id` - Zone ID of the ALB (for Route53)
- `alb_security_group_id` - Security group ID of the ALB
- `runtime_endpoint_url` - Full HTTPS URL (https://alb-dns-name)

### Target Group Outputs
- `target_group_arn` - ARN of the target group
- `target_group_name` - Name of the target group

### ECS Outputs
- `ecs_cluster_id` - ID of the ECS cluster
- `ecs_cluster_name` - Name of the ECS cluster
- `ecs_cluster_arn` - ARN of the ECS cluster
- `ecs_service_id` - ID of the ECS service
- `ecs_service_name` - Name of the ECS service
- `ecs_service_security_group_id` - Security group ID of the ECS service
- `ecs_task_definition_arn` - ARN of the task definition
- `ecs_task_definition_family` - Family of the task definition

### IAM Outputs
- `ecs_task_execution_role_arn` - ARN of the task execution role
- `ecs_task_execution_role_name` - Name of the task execution role
- `ecs_task_role_arn` - ARN of the task role
- `ecs_task_role_name` - Name of the task role

### Encryption Outputs
- `kms_key_id` - ID of the KMS key
- `kms_key_arn` - ARN of the KMS key
- `kms_key_alias` - Alias of the KMS key

### Logging Outputs
- `cloudwatch_log_group_name` - Name of the CloudWatch log group
- `cloudwatch_log_group_arn` - ARN of the CloudWatch log group

### Listener Outputs
- `https_listener_arn` - ARN of the HTTPS listener

---

## Usage Examples

### Example 1: Basic Production Setup

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore"
  environment = "production"

  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
  public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]

  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

  microsoft_oauth_client_id  = "12345678-1234-1234-1234-123456789012"
  microsoft_oauth_tenant_id  = "87654321-4321-4321-4321-210987654321"
  microsoft_oauth_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:oauth-secret"

  tags = {
    Project = "AgentCore"
    Owner   = "Platform Team"
  }
}
```

### Example 2: With Auto Scaling

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore"
  environment = "production"

  # ... (other required variables)

  # Compute Configuration
  cpu           = 2048
  memory        = 4096
  desired_count = 3

  # Auto Scaling
  enable_autoscaling        = true
  autoscaling_min_capacity  = 3
  autoscaling_max_capacity  = 20
  autoscaling_target_cpu    = 70
  autoscaling_target_memory = 80

  tags = {
    Project = "AgentCore"
  }
}
```

### Example 3: Development Environment

```hcl
module "agentcore_gateway_dev" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore"
  environment = "dev"

  # ... (other required variables)

  # Smaller resources for dev
  cpu           = 512
  memory        = 1024
  desired_count = 1

  # Cost optimization
  enable_container_insights = false
  log_retention_days        = 7
  enable_deletion_protection = false

  # Allow access only from office IP
  alb_ingress_cidr_blocks = ["203.0.113.0/24"]

  tags = {
    Project     = "AgentCore"
    Environment = "Development"
  }
}
```

### Example 4: With Custom Health Checks

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... (required variables)

  # Custom health check configuration
  health_check_path                = "/api/health"
  health_check_interval            = 15
  health_check_timeout             = 10
  health_check_healthy_threshold   = 3
  health_check_unhealthy_threshold = 2
  health_check_matcher             = "200,204"

  tags = {
    Project = "AgentCore"
  }
}
```

### Example 5: With Host-Based Routing

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... (required variables)

  # Host-based routing
  host_based_routing_hosts = [
    "api.yourdomain.com",
    "agentcore.yourdomain.com"
  ]

  tags = {
    Project = "AgentCore"
  }
}
```

### Example 6: With Additional Environment Variables

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... (required variables)

  # Additional environment variables for the container
  additional_container_environment_variables = {
    LOG_LEVEL          = "debug"
    MAX_CONNECTIONS    = "1000"
    REQUEST_TIMEOUT    = "60"
    FEATURE_FLAG_OAUTH = "true"
    API_VERSION        = "v2"
  }

  tags = {
    Project = "AgentCore"
  }
}
```

### Example 7: With Workload Identity

```hcl
# Create a separate IAM role for workload identity
resource "aws_iam_role" "workload_identity" {
  name = "agentcore-workload-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::123456789012:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach policies to the workload identity role
resource "aws_iam_role_policy" "workload_s3_access" {
  role = aws_iam_role.workload_identity.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}

module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... (required variables)

  # Workload Identity
  workload_identity_role_arn = aws_iam_role.workload_identity.arn

  tags = {
    Project = "AgentCore"
  }
}
```

---

## Common Scenarios

### Scenario 1: Multiple Environments (Dev, Staging, Prod)

Create separate `.tfvars` files for each environment:

**environments/dev.tfvars:**
```hcl
name        = "agentcore"
environment = "dev"

vpc_id             = "vpc-dev123"
private_subnet_ids = ["subnet-dev-private-1", "subnet-dev-private-2"]
public_subnet_ids  = ["subnet-dev-public-1", "subnet-dev-public-2"]

container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:dev"
cpu             = 512
memory          = 1024
desired_count   = 1

enable_autoscaling         = false
enable_container_insights  = false
enable_deletion_protection = false
log_retention_days         = 7
```

**environments/prod.tfvars:**
```hcl
name        = "agentcore"
environment = "prod"

vpc_id             = "vpc-prod123"
private_subnet_ids = ["subnet-prod-private-1", "subnet-prod-private-2", "subnet-prod-private-3"]
public_subnet_ids  = ["subnet-prod-public-1", "subnet-prod-public-2", "subnet-prod-public-3"]

container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0"
cpu             = 2048
memory          = 4096
desired_count   = 5

enable_autoscaling        = true
autoscaling_min_capacity  = 5
autoscaling_max_capacity  = 50
enable_container_insights = true
log_retention_days        = 90
```

**Deploy:**
```bash
# Development
terraform apply -var-file=environments/dev.tfvars

# Production
terraform apply -var-file=environments/prod.tfvars
```

### Scenario 2: Blue-Green Deployment

```hcl
# Blue Environment
module "agentcore_gateway_blue" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore-blue"
  environment = "production"

  # ... other config

  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v1.0.0"

  tags = {
    Deployment = "Blue"
  }
}

# Green Environment
module "agentcore_gateway_green" {
  source = "./terraform-aws-agentcore-gateway"

  name        = "agentcore-green"
  environment = "production"

  # ... other config

  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/agentcore-gateway:v2.0.0"

  tags = {
    Deployment = "Green"
  }
}
```

### Scenario 3: Adding Route53 DNS

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... module configuration
}

# Create Route53 record
resource "aws_route53_record" "agentcore" {
  zone_id = "Z1234567890ABC"  # Your hosted zone ID
  name    = "api.yourdomain.com"
  type    = "A"

  alias {
    name                   = module.agentcore_gateway.alb_dns_name
    zone_id                = module.agentcore_gateway.alb_zone_id
    evaluate_target_health = true
  }
}

output "api_url" {
  value = "https://${aws_route53_record.agentcore.name}"
}
```

### Scenario 4: Adding CloudWatch Alarms

```hcl
module "agentcore_gateway" {
  source = "./terraform-aws-agentcore-gateway"

  # ... module configuration
}

# Create SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "agentcore-alerts"
}

# Alarm for high CPU
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "agentcore-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85

  dimensions = {
    ClusterName = module.agentcore_gateway.ecs_cluster_name
    ServiceName = module.agentcore_gateway.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Alarm for unhealthy targets
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "agentcore-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0

  dimensions = {
    TargetGroup  = module.agentcore_gateway.target_group_arn
    LoadBalancer = module.agentcore_gateway.alb_arn
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## Troubleshooting

### Issue 1: "terraform init" fails

**Error:**
```
Error: Failed to install provider
```

**Solution:**
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init
```

### Issue 2: "terraform apply" fails with permission denied

**Error:**
```
Error: creating ECS Cluster: AccessDeniedException
```

**Solution:**
Ensure your AWS credentials have the necessary permissions. Check:
```bash
aws sts get-caller-identity

# Should show your account ID and role/user
```

### Issue 3: ECS tasks fail to start

**Check 1: Container Image**
```bash
# Verify image exists and is accessible
aws ecr describe-images \
  --repository-name agentcore-gateway \
  --region us-east-1
```

**Check 2: Task Logs**
```bash
# View CloudWatch logs
aws logs tail /ecs/agentcore-production-agentcore-gateway --follow
```

**Check 3: Task Definition**
```bash
# Describe task definition
aws ecs describe-task-definition \
  --task-definition agentcore-production-agentcore-gateway \
  --region us-east-1
```

### Issue 4: Health checks failing

**Check health check endpoint:**
```bash
# Get the ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health check endpoint
curl -v https://${ALB_DNS}/health
```

**Common causes:**
- Health check path doesn't exist in your application
- Container port mismatch
- Application not listening on 0.0.0.0 (listening on localhost only)

**Fix:**
Update health_check_path variable or fix your application.

### Issue 5: Cannot access the endpoint

**Check 1: Security Groups**
```bash
# Verify ALB security group allows ingress
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id) \
  --region us-east-1
```

**Check 2: Target Health**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region us-east-1
```

### Issue 6: OAuth authentication not working

**Check 1: Secret exists**
```bash
# Verify secret
aws secretsmanager get-secret-value \
  --secret-id agentcore-oauth-secret \
  --region us-east-1
```

**Check 2: Task Role Permissions**
```bash
# Verify task role has permission
aws iam get-role-policy \
  --role-name $(terraform output -raw ecs_task_role_name) \
  --policy-name agentcore-production-ecs-task-policy \
  --region us-east-1
```

### Issue 7: High costs

**Optimize:**
```hcl
# Reduce resources for non-prod
cpu           = 512   # Instead of 2048
memory        = 1024  # Instead of 4096
desired_count = 1     # Instead of 5

# Reduce log retention
log_retention_days = 7  # Instead of 90

# Disable Container Insights in dev
enable_container_insights = false
```

---

## Best Practices

### 1. Use Remote State

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "agentcore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 2. Use Terraform Workspaces for Environments

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspace
terraform workspace select prod

# Use workspace in configuration
locals {
  environment = terraform.workspace
}
```

### 3. Secure Your tfvars Files

```bash
# Add to .gitignore
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars" >> .gitignore
echo ".terraform/" >> .gitignore
echo "*.tfstate" >> .gitignore
```

### 4. Use AWS Systems Manager Parameter Store for Sensitive Data

```hcl
# Instead of hardcoding secrets
data "aws_ssm_parameter" "oauth_client_id" {
  name = "/agentcore/oauth/client_id"
}

module "agentcore_gateway" {
  # ...
  microsoft_oauth_client_id = data.aws_ssm_parameter.oauth_client_id.value
}
```

### 5. Tag Everything

```hcl
locals {
  common_tags = {
    Project     = "AgentCore"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "platform-team@company.com"
    CostCenter  = "Engineering"
    Compliance  = "PCI-DSS"
  }
}

module "agentcore_gateway" {
  # ...
  tags = local.common_tags
}
```

### 6. Use Data Sources for Existing Resources

```hcl
# Instead of hardcoding VPC ID
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["main-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "private"
  }
}

module "agentcore_gateway" {
  vpc_id             = data.aws_vpc.main.id
  private_subnet_ids = data.aws_subnets.private.ids
  # ...
}
```

### 7. Enable Terraform Locking

Use DynamoDB for state locking:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "agentcore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # Prevents concurrent modifications
  }
}
```

### 8. Plan Before Apply

```bash
# Always review changes
terraform plan -out=tfplan

# Review the plan
terraform show tfplan

# Apply only if everything looks good
terraform apply tfplan
```

### 9. Use Module Versioning

```hcl
module "agentcore_gateway" {
  source  = "git::https://github.com/yourorg/terraform-aws-agentcore-gateway.git?ref=v1.0.0"
  # or
  source  = "./terraform-aws-agentcore-gateway"

  # ...
}
```

### 10. Monitor and Alert

Set up comprehensive monitoring:

```hcl
# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "agentcore" {
  dashboard_name = "agentcore-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "ECS Service Metrics"
        }
      }
    ]
  })
}
```

---

## Summary Checklist

Before deploying to production, ensure:

- [ ] VPC with public and private subnets configured
- [ ] SSL/TLS certificate created in ACM
- [ ] Microsoft OAuth app registered in Azure AD
- [ ] OAuth client secret stored in AWS Secrets Manager
- [ ] Container image built and pushed to ECR
- [ ] All required variables filled in terraform.tfvars
- [ ] AWS credentials configured with sufficient permissions
- [ ] Reviewed and understood the security implications
- [ ] Configured monitoring and alerting
- [ ] Tested in a non-production environment first
- [ ] Documented any customizations
- [ ] Set up backup and disaster recovery procedures
- [ ] Configured CI/CD pipeline (if applicable)

---

## Support and Additional Resources

### AWS Documentation
- [ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Certificate Manager](https://docs.aws.amazon.com/acm/)

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Modules](https://www.terraform.io/docs/language/modules/index.html)

### Microsoft OAuth Documentation
- [Microsoft Identity Platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- [OAuth 2.0 Authorization Code Flow](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)

---

**Module Version:** 1.0.0
**Last Updated:** 2026-02-19
**Terraform Version:** >= 1.5
**AWS Provider Version:** >= 5.0
