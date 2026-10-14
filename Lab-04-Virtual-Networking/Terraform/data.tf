# Lab 02: network resource group, prod VNet, data subnet, private DNS zone
data "azurerm_resource_group" "network" {
  name = "rg-solstice-network"
}

data "azurerm_virtual_network" "prod" {
  name                = "vnet-solstice-prod"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "prod_data" {
  name                 = "subnet-data"
  virtual_network_name = data.azurerm_virtual_network.prod.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "rg-solstice-data"
}

# Lab 03: prod compute subnet and its NSG
data "azurerm_subnet" "prod_compute" {
  name                 = "subnet-compute"
  virtual_network_name = data.azurerm_virtual_network.prod.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

data "azurerm_network_security_group" "prod_compute" {
  name                = "nsg-prod-compute"
  resource_group_name = data.azurerm_resource_group.network.name
}