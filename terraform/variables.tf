variable "region" {
  description = "AWS region"
  type        = string
}

variable "project" {
  description = "Name prefix for resources"
  type        = string
  default     = "microserver"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/devops-key.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH"
  type        = list(string)
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach Nginx on port 80"
  type        = list(string)
}

variable "ecr_repositories" {
  description = "ECR repositories to create"
  type        = list(string)
  default     = ["user-service", "product-service", "order-service"]
}
