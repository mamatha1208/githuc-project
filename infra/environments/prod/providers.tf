terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Remote state in Azure Storage — keeps state out of git and lets CI and
  # local runs share the same source of truth. Create the storage account /
  # container once by hand (or via a bootstrap script) before first `init`,
  # since Terraform can't create the backend it's about to use. Each
  # environment gets its own state key so prod/staging/etc. never collide.
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateuniquename001" # must be globally unique
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # In CI, auth is via OIDC federated credentials (ARM_USE_OIDC=true plus
  # ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID env vars set by the
  # azure/login action) — no client secret stored anywhere.
}
