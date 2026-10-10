output "api_public_ip" {
  value = azurerm_public_ip.api.ip_address
}

output "acr_name" {
  value = azurerm_container_registry.solstice.name
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.dashboard_api.name
}

output "admin_app_hostname" {
  value = azurerm_linux_web_app.admin.default_hostname
}