variable "prefix" {
  description = "Short name used to prefix all resources, e.g. 'myapp'"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (used in resource naming/tags)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "container_image_tag" {
  description = <<-EOT
    Tag of the image in ACR to deploy, e.g. the git SHA pushed by the
    scan-and-publish CI job. Passed in via -var from the deploy workflow so
    each apply deploys exactly the image that was built, scanned, and pushed.
  EOT
  type        = string
}

variable "container_port" {
  description = "Port the app listens on inside the container"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "HTTP path used for liveness/readiness probes"
  type        = string
  default     = "/healthz"
}

variable "cpu" {
  description = "vCPU allocated to the container app (Container Apps billing unit)"
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memory allocated to the container app"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 3
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
