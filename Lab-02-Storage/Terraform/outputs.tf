output "storage_account_name" {
  value = azurerm_storage_account.solstice.name
}

output "private_dns_zone_name" {
  value = azurerm_private_dns_zone.blob.name
}

output "prod_vnet_id" {
  value = azurerm_virtual_network.prod.id
}