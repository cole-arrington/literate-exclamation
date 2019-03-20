variable "app_count" {
  description = "Number of docker containers to run"
  default     = 1
}

variable "app_port" {
  description = "Port that app is running on"
  default     = 5000
}

variable "aws_credentials" {
  description = "AWS credentials directory"
  default     = "$HOME/.aws/credentials"
}

variable "aws_profile" {
  description = "AWS profile"
  default     = "default"
}

variable "aws_region" {
  description = "AWS region for app"
  default     = "us-east-1"
}

variable "az_number" {
  description = "Number of availability zones per region"
  default     = "2"
}

variable "cidr_block" {
  description = "Default CIDR block"
  default     = "0.0.0.0/0"
}

variable "fargate_cpu" {
  description = "Fargate CPU amount"
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate memory amount"
  default     = "512"
}

variable "lb_port" {
  description = "Load balancer port"
  default     = 80
}

variable "ecs_task_execution_role" {
  description = "Role arn for the ecsTaskExecutionRole"
  default     = "arn:aws:iam::415868856706:role/ecsTaskExecutionRole"
}