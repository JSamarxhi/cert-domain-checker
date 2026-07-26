# ---------------------------------------------------------------------------
# Resource group
#
# A container for everything below. Deleting it deletes all of it, which is
# what the portal did manually. Terraform will manage that lifecycle instead.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}"
  location = var.location
}

# ---------------------------------------------------------------------------
# Log Analytics workspace
#
# Container Apps sends stdout/stderr here. The portal created this implicitly
# when it built the environment. Declaring it explicitly means it is visible,
# versioned, and destroyed along with everything else.
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018" # pay per GB ingested; 5GB/month is free
  retention_in_days   = 30
}

# ---------------------------------------------------------------------------
# Container Apps environment
#
# The shared boundary that container apps run inside: networking, logging,
# and the scaling infrastructure.
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "main" {
  name                = "cae-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Referencing another resource's attribute creates an implicit dependency.
  # Terraform reads these references to work out the correct creation order.
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# ---------------------------------------------------------------------------
# The container app itself
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "main" {
  name                         = "ca-${var.prefix}"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id

  # "Single" = one active revision at a time. New deploys replace the old one.
  # "Multiple" would allow blue/green and traffic splitting.
  revision_mode = "Single"

  template {
    # Scale to zero when idle. This is the setting that keeps cost at zero:
    # no replicas running means no vCPU-seconds billed.
    min_replicas = 0
    max_replicas = 1

    container {
      name   = var.prefix
      image  = var.container_image
      cpu    = 0.25 # valid CPU/memory pairs are fixed; 0.25 pairs with 0.5Gi
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true            # reachable from the public internet
    target_port      = var.target_port # must match what the container listens on
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
