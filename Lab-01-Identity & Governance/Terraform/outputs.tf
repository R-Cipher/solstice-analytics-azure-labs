output "resource_group_id" {
  value = azurerm_resource_group.core.id
}

output "client_success_group_object_id" {
  value = azuread_group.client_success.object_id
}