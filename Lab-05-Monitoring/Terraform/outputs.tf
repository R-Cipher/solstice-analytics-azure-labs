output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.solstice.workspace_id
}

output "recovery_vault_name" {
  value = azurerm_recovery_services_vault.solstice.name
}