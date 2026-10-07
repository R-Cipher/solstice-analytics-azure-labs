locals {
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }
}

# Resources groups

resource "azurerm_resource_group" "data" {
  name     = "rg-solstice-data"
  location = local.location
  tags     = local.tags
}

resource "azurerm_resource_group" "network" {
  name     = "rg-solstice-network"
  location = local.location
  tags     = local.tags
}

locals {
  governed_rgs = {
    data    = azurerm_resource_group.data.id
    network = azurerm_resource_group.network.id
  }
}

resource "azurerm_resource_group_policy_assignment" "require_costcenter" {
  for_each             = local.governed_rgs
  name                 = "require-costcenter"
  display_name         = "Require CostCenter Tag"
  resource_group_id    = each.value
  policy_definition_id = data.azurerm_policy_definition.require_costcenter.id
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  for_each             = local.governed_rgs
  name                 = "allowed-locations"
  display_name         = "Allowed Locations: East US, East US 2"
  resource_group_id    = each.value
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  parameters = jsonencode({
    "listOfAllowedLocations" = {
      "value" = ["eastus", "eastus2"]
    }
  })
}

resource "azurerm_virtual_network" "prod" {
  name                = "vnet-solstice-prod"
  resource_group_name = azurerm_resource_group.network.name
  location            = local.location
  address_space       = ["10.1.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "data" {
  name                              = "subnet-data"
  resource_group_name               = azurerm_resource_group.network.name
  virtual_network_name              = azurerm_virtual_network.prod.name
  address_prefixes                  = ["10.1.2.0/24"]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_storage_account" "solstice" {
  name                            = "stsolsticedata${var.name_suffix}"
  resource_group_name             = azurerm_resource_group.data.name
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "RAGZRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = !var.lock_down_public_access
  tags                            = local.tags
}

resource "azurerm_storage_container" "raw" {
  name               = "raw-manifests"
  storage_account_id = azurerm_storage_account.solstice.id
}

resource "azurerm_storage_container" "processed" {
  name               = "processed"
  storage_account_id = azurerm_storage_account.solstice.id
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.solstice.id

  rule {
    name    = "tier-and-expire-raw-manifests"
    enabled = true

    filters {
      prefix_match = ["raw-manifests/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        tier_to_cold_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than       = 365
      }
    }
  }
}

resource "azurerm_role_assignment" "client_success_processed" {
  scope                = azurerm_storage_container.processed.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.client_success.object_id
  principal_type       = "Group"
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.data.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "prod" {
  name                 = "link-vnet-solstice-prod"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.prod.id
  registration_enabled = false
  tags                 = local.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-stsolsticedata-blob"
  location            = local.location
  resource_group_name = azurerm_resource_group.data.name
  subnet_id           = azurerm_subnet.data.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-stsolsticedata"
    private_connection_resource_id = azurerm_storage_account.solstice.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}