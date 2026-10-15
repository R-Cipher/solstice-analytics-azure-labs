data "azurerm_subscription" "current" {}

# Lab 01
data "azurerm_policy_definition" "require_costcenter" {
  name = "require-costcenter-tag"
}

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
}

# Lab 02
data "azurerm_storage_account" "solstice" {
  name                = "stsolsticedata${var.name_suffix}"
  resource_group_name = "rg-solstice-data"
}

# Lab 03
data "azurerm_virtual_machine_scale_set" "dashboard_api" {
  name                = "vmss-dashboard-api"
  resource_group_name = "rg-solstice-compute"
}

# Lab 04
data "azurerm_virtual_machine" "ops" {
  name                = "vm-solstice-ops"
  resource_group_name = "rg-solstice-network"
}