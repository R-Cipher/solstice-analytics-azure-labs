output "nat_public_ips" {
  value = { for k, v in azurerm_public_ip.nat : k => v.ip_address }
}

output "ops_vm_name" {
  value = azurerm_linux_virtual_machine.ops.name
}