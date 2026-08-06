locals {
  name = "${var.prefix}-${var.environment}"
  tags = merge(var.tags, { environment = var.environment, managed_by = "terraform" })
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "this" {
  name                = replace("${var.prefix}${var.environment}acr", "-", "") # alnum only
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard"
  admin_enabled       = false # pull is via managed identity, not admin creds
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Container Apps environment (shared compute/network boundary)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name}-logs"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${local.name}-env"
  resource_group_name       = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags
}

# ---------------------------------------------------------------------------
# Container App
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "this" {
  name                         = "${local.name}-app"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  # Multiple revision mode is what makes safe rollout / rollback possible:
  # each apply creates a NEW revision instead of overwriting the running
  # one, and traffic can be shifted or reverted between revisions without
  # a rebuild.
  revision_mode = "Multiple"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = "System" # pull using the app's own managed identity
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.prefix
      image  = "${azurerm_container_registry.this.login_server}/${var.prefix}:${var.container_image_tag}"
      cpu    = var.cpu
      memory = var.memory

      liveness_probe {
        transport = "HTTP"
        port      = var.container_port
        path      = var.health_check_path
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.container_port
        path      = var.health_check_path
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.container_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.tags
}

# Grant the Container App's managed identity permission to pull from ACR —
# no registry username/password anywhere in config or CI.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.this.identity[0].principal_id
}
