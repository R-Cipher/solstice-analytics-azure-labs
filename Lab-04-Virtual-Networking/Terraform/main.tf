locals {
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }
}

# The CostCenter and Allowed Locations policies were already assigned to
# rg-solstice-network in Lab 02, so every resource below inherits them.

# ---------- Hub and dev spoke ----------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-solstice-hub"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "shared_services" {
  name                 = "subnet-shared-services"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "dev" {
  name                = "vnet-solstice-dev"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  address_space       = ["10.2.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "dev_compute" {
  name                 = "subnet-compute"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.2.1.0/24"]
  default_outbound_access_enabled = false
}

# ---------- Peering: hub <-> prod and hub <-> dev. Prod and dev are NOT peered. ----------
resource "azurerm_virtual_network_peering" "hub_to_prod" {
  name                      = "hub-to-prod"
  resource_group_name       = data.azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = data.azurerm_virtual_network.prod.id
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                      = "prod-to-hub"
  resource_group_name       = data.azurerm_resource_group.network.name
  virtual_network_name      = data.azurerm_virtual_network.prod.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

resource "azurerm_virtual_network_peering" "hub_to_dev" {
  name                      = "hub-to-dev"
  resource_group_name       = data.azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.dev.id
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  name                      = "dev-to-hub"
  resource_group_name       = data.azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.dev.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

# ---------- NSGs ----------
# Prod compute NSG (created in Lab 03): add SSH from the hub ops subnet, block dev
resource "azurerm_network_security_rule" "allow_lb_health_probe" {
  name                        = "allow-lb-health-probe"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.network.name
  network_security_group_name = data.azurerm_network_security_group.prod_compute.name
}

resource "azurerm_network_security_rule" "allow_ssh_from_ops" {
  name                        = "allow-ssh-from-ops"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.network.name
  network_security_group_name = data.azurerm_network_security_group.prod_compute.name
}

resource "azurerm_network_security_rule" "deny_dev" {
  name                        = "deny-dev-inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.2.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.network.name
  network_security_group_name = data.azurerm_network_security_group.prod_compute.name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny-all-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.network.name
  network_security_group_name = data.azurerm_network_security_group.prod_compute.name
}

# Data subnet (private endpoint): only the tiers that need storage may connect
resource "azurerm_network_security_group" "prod_data" {
  name                = "nsg-prod-data"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  tags                = local.tags

  security_rule {
    name                       = "allow-https-from-compute"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https-from-batch"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.1.3.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https-from-hub-ops"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "prod_data" {
  subnet_id                 = data.azurerm_subnet.prod_data.id
  network_security_group_id = azurerm_network_security_group.prod_data.id
}

# Dev compute: explicit deny from prod address space (defense in depth; dev and prod are not peered)
resource "azurerm_network_security_group" "dev_compute" {
  name                = "nsg-dev-compute"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  tags                = local.tags

  security_rule {
    name                       = "deny-from-prod"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev_compute" {
  subnet_id                 = azurerm_subnet.dev_compute.id
  network_security_group_id = azurerm_network_security_group.dev_compute.id
}

# ---------- NAT gateways: controlled outbound for hub and prod compute ----------
# A NAT gateway can only attach to subnets in its own VNet, so there is one per VNet.
locals {
  nat_subnets = {
    hub          = azurerm_subnet.shared_services.id
    prod-compute = data.azurerm_subnet.prod_compute.id
  }
}

resource "azurerm_public_ip" "nat" {
  for_each            = local.nat_subnets
  name                = "pip-nat-${each.key}"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  for_each            = local.nat_subnets
  name                = "natgw-${each.key}"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  for_each             = local.nat_subnets
  nat_gateway_id       = azurerm_nat_gateway.this[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each       = local.nat_subnets
  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.this[each.key].id

  depends_on = [azurerm_nat_gateway_public_ip_association.this]
}

# ---------- Private DNS: let the hub resolve the Lab 02 private endpoint ----------
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                 = "link-vnet-solstice-hub"
  private_dns_zone_id  = data.azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.hub.id
  registration_enabled = false
  tags                 = local.tags
}

# ---------- Ops VM in the hub (no public IP): test point now, backup target in Lab 05 ----------
resource "azurerm_network_interface" "ops" {
  name                = "nic-solstice-ops"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_services.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "ops" {
  name                  = "vm-solstice-ops"
  resource_group_name   = data.azurerm_resource_group.network.name
  location              = local.location
  size                  = "Standard_D2nlds_v6"
  admin_username        = "solsticeadmin"
  network_interface_ids = [azurerm_network_interface.ops.id]
  tags                  = local.tags

  admin_ssh_key {
    username   = "solsticeadmin"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  # Lab 05 installs the Azure Monitor Agent, which authenticates with this identity
  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  # Outbound (apt, extensions) goes through the hub NAT gateway
  depends_on = [azurerm_subnet_nat_gateway_association.this]
}