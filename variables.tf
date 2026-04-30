# =============================================================================
# GENERAL SETTINGS
# =============================================================================
variable "project_name" {
  description = "Nama project, digunakan sebagai prefix semua resource"
  type        = string
  default     = "koperasi-merah-putih"
}

variable "environment" {
  description = "Nama environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "owner_name" {
  description = "Nama pemilik project"
  type        = string
  default     = "DevTeam"
}

variable "aws_region" {
  description = "AWS Region yang digunakan"
  type        = string
  default     = "ap-southeast-1" # Singapore - terdekat dari Indonesia
}

# =============================================================================
# NETWORKING
# =============================================================================
variable "vpc_cidr" {
  description = "CIDR block untuk VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks untuk public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks untuk private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones yang digunakan"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# =============================================================================
# ELASTIC BEANSTALK
# =============================================================================
variable "eb_solution_stack" {
  description = "Solution stack untuk Elastic Beanstalk"
  type        = string
  # Node.js 18 pada Amazon Linux 2 (free tier eligible)
  default = "64bit Amazon Linux 2023 v6.1.4 running Node.js 20"
}

variable "eb_instance_type" {
  description = "EC2 instance type untuk Elastic Beanstalk (free tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "eb_min_instances" {
  description = "Minimum jumlah instance Elastic Beanstalk"
  type        = number
  default     = 1
}

variable "eb_max_instances" {
  description = "Maximum jumlah instance Elastic Beanstalk"
  type        = number
  default     = 1 # Free tier: batasi 1 instance
}

# =============================================================================
# RDS DATABASE
# =============================================================================
variable "db_name" {
  description = "Nama database"
  type        = string
  default     = "gbappdb"
}

variable "db_username" {
  description = "Username database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Password database (minimum 8 karakter)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class (free tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage RDS dalam GB (free tier: max 20GB)"
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Versi database engine"
  type        = string
  default     = "8.0"
}

# =============================================================================
# LAMBDA
# =============================================================================
variable "lambda_runtime" {
  description = "Runtime untuk Lambda functions"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Timeout Lambda dalam detik"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory Lambda dalam MB (free tier: 128MB sangat efisien)"
  type        = number
  default     = 128
}

# =============================================================================
# DYNAMODB - LOGGING
# =============================================================================
variable "dynamodb_billing_mode" {
  description = "Billing mode DynamoDB (PAY_PER_REQUEST untuk free tier)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# =============================================================================
# S3
# =============================================================================
variable "s3_deployment_bucket_name" {
  description = "Nama S3 bucket untuk deployment artifacts"
  type        = string
  default     = ""
}

variable "s3_app_bucket_name" {
  description = "Nama S3 bucket untuk application storage"
  type        = string
  default     = ""
}

# =============================================================================
# AMPLIFY
# =============================================================================
variable "github_repo_url" {
  description = "URL GitHub repository (format: https://github.com/username/repo)"
  type        = string
  default     = "https://github.com/your-org/your-frontend-repo"
}

variable "github_access_token" {
  description = "GitHub Personal Access Token untuk Amplify"
  type        = string
  sensitive   = true
  default     = ""
}

variable "amplify_branch_name" {
  description = "Branch GitHub untuk Amplify"
  type        = string
  default     = "main"
}

# =============================================================================
# BLUE/GREEN DEPLOYMENT
# =============================================================================
variable "active_color" {
  description = "Warna environment yang aktif saat ini (blue atau green)"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color harus bernilai 'blue' atau 'green'."
  }
}

variable "blue_version_label" {
  description = "Version label untuk environment Blue"
  type        = string
  default     = "v1.0.0-blue"
}

variable "green_version_label" {
  description = "Version label untuk environment Green"
  type        = string
  default     = "v1.0.1-green"
}
