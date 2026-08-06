# Deploy target: Azure Container Apps, pulling the image pushed to GHCR by
# the CI pipeline (see .github/workflows/ci.yml). Container Apps was chosen
# over AKS for a service this small - no cluster to operate, built-in
# HTTPS ingress, and scale-to-N replicas out of the box.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Remote state so CI runs and local `terraform apply` share the same
  # state file. Values are injected at `terraform init` time via
  # -backend-config flags (see the CI workflow) rather than hardcoded here,
  # so this block intentionally stays empty.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "image_tag" {
  description = "Container image tag to deploy (the git SHA from CI)"
  type        = string
}

variable "ghcr_owner" {
  description = "GitHub org/user that owns the GHCR package (github.repository_owner)"
  type        = string
}

variable "ghcr_username" {
  description = "Username used to authenticate Container Apps' pull from GHCR"
  type        = string
}

variable "ghcr_token" {
  description = "Token with read:packages scope, used as the GHCR pull secret"
  type        = string
  sensitive   = true
}

locals {
  image = "ghcr.io/${lower(var.ghcr_owner)}/widget-api:${var.image_tag}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-servicelink-widget-api"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-servicelink-widget-api"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-servicelink-widget-api"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_container_app" "this" {
  name                         = "ca-widget-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name

  # Single revision mode keeps rollback simple: the previous revision stays
  # provisioned until the new one is healthy, and `az containerapp revision
  # activate <previous>` (or re-running `terraform apply` with the prior
  # image_tag) rolls back in seconds without a rebuild.
  revision_mode = "Single"

  secret {
    name  = "ghcr-token"
    value = var.ghcr_token
  }

  registry {
    server                = "ghcr.io"
    username              = var.ghcr_username
    password_secret_name  = "ghcr-token"
  }

  template {
    container {
      name   = "widget-api"
      image  = local.image
      cpu    = 0.25
      memory = "0.5Gi"

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

output "app_url" {
  description = "Public HTTPS URL of the deployed service"
  value       = "https://${azurerm_container_app.this.latest_revision_fqdn}"
}
