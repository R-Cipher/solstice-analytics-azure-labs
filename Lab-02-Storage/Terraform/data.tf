data "azuread_group" "client_success" {
  display_name     = "sg-client-success"
  security_enabled = true
}

data "azurerm_policy_definition" "require_costcenter" {
  name = "require-costcenter-tag"
}

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
}