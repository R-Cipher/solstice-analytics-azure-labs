resource "azuread_group" "client_success" {
  display_name     = "sg-client-success"
  security_enabled = true
}

resource "azuread_group" "contractors" {
  display_name     = "sg-contractors-external"
  security_enabled = true
}

resource "azurerm_resource_group" "core" {
  name     = "rg-solstice-core"
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }
}

resource "azurerm_role_definition" "dashboard_operator" {
  name        = "Dashboard Operator"
  scope       = azurerm_resource_group.core.id
  description = "Read/Write on Web Apps and Storage, no delete on networking or Key Vault"
  permissions {
    actions = [
      "*/read",
      "Microsoft.Web/sites/*",
      "Microsoft.Storage/storageAccounts/*",
    ]
    not_actions = [
      "Microsoft.Network/*/delete",
      "Microsoft.KeyVault/*/delete",
    ]
  }
  assignable_scopes = [azurerm_resource_group.core.id]
}

resource "azurerm_role_assignment" "client_success" {
  scope              = azurerm_resource_group.core.id
  role_definition_id = azurerm_role_definition.dashboard_operator.role_definition_resource_id
  principal_id       = azuread_group.client_success.object_id
  principal_type     = "Group"
}

resource "azurerm_policy_definition" "require_costcenter_tag" {
  name         = "require-costcenter-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require CostCenter Tag"
  policy_rule = jsonencode({
    if = {
      field  = "tags['CostCenter']"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "require_costcenter" {
  name                 = "require-costcenter"
  display_name         = "Require CostCenter Tag"
  resource_group_id    = azurerm_resource_group.core.id
  policy_definition_id = azurerm_policy_definition.require_costcenter_tag.id
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Locations: East US, East US 2"
  resource_group_id    = azurerm_resource_group.core.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  parameters = jsonencode({
    "listOfAllowedLocations" = {
      "value" = ["eastus", "eastus2"]
    }
  })
}

resource "azurerm_management_lock" "core" {
  name       = "core-cannotdelete"
  scope      = azurerm_resource_group.core.id
  lock_level = "CanNotDelete"
  depends_on = [
    azurerm_role_assignment.client_success,
    azurerm_resource_group_policy_assignment.require_costcenter,
    azurerm_resource_group_policy_assignment.allowed_locations,
  ]
}