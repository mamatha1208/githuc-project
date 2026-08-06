module "app" {
  source = "../../modules/container_apps"

  prefix              = var.prefix
  environment         = "prod"
  location            = var.location
  container_image_tag = var.container_image_tag

  # Prod sizing — bump these here without touching the module itself.
  cpu          = 1.0
  memory       = "2Gi"
  min_replicas = 2
  max_replicas = 5

  tags = {
    cost_center = "engineering"
  }
}
