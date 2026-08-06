variable "prefix" {
  description = "Short name used to prefix all resources, e.g. 'myapp'"
  type        = string
  default     = "myapp"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "container_image_tag" {
  description = "Tag of the image in ACR to deploy (git SHA), passed in via -var from CI"
  type        = string
}
