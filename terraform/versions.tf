# Pins Terraform itself and the providers it downloads.
# Pinning matters: an unpinned provider can change behavior between runs,
# which defeats the point of reproducible infrastructure.

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm" # where to download it from
      version = "~> 4.0"            # allow 4.x, but not 5.0 (breaking changes)
    }
  }
}

# Configures the Azure provider. It picks up your credentials automatically
# from `az login`, so no secrets live in this file.
provider "azurerm" {
  features {} # required block, even when empty

  subscription_id = var.subscription_id
}
