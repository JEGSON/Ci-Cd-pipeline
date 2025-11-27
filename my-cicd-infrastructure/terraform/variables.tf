variable "aws_region" {
    description = "AWS region for resources"
    type = string
    default = "us-east-1"

}

variable "project_name" {
    description = "Project name for resource naming"
    type = string
    default = "retail-store"
  
}

variable "environment" {
    description = "Environment name (dev, staging, prod)"
    type = string
    default = "dev"
  
}

variable "vpc_cidr" {
    description = "CIDR block for VPC"
    type = string
    default = "10.0.0.0/16"
  
}

variable "availability_zones" {
  description = "Availability zones for the region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "mydb"
}

variable "container_port" {
  description = "Port exposed by the docker containers"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the load balancer"
  type        = string
  default     = "/actuator/health"
}

variable "manage_db_credentials_with_secrets_manager" {
  description = "If true, create a secret in AWS Secrets Manager for the DB credentials."
  type        = bool
  default     = true
}

variable "services" {
  description = "A list of service names to create ECR repos and log groups for."
  type        = list(string)
  default     = ["ui", "catalog", "cart", "orders", "checkout"]
}
