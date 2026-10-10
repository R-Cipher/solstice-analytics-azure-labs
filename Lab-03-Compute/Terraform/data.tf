data "azurerm_policy_definition" "require_costcenter" {
  name = "require-costcenter-tag"
}

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
}

data "azurerm_resource_group" "network" {
  name = "rg-solstice-network"
}

data "azurerm_virtual_network" "prod" {
  name                = "vnet-solstice-prod"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_storage_account" "solstice" {
  name                = "stsolsticedata${var.name_suffix}"
  resource_group_name = "rg-solstice-data"
}

