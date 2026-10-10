locals {
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }

  # Container-scope IDs for the Lab 02 containers
  raw_container_id       = "${data.azurerm_storage_account.solstice.id}/blobServices/default/containers/raw-manifests"
  processed_container_id = "${data.azurerm_storage_account.solstice.id}/blobServices/default/containers/processed"
}

# ---------- Resource group + Lab 01 governance ----------
resource "azurerm_resource_group" "compute" {
  name     = "rg-solstice-compute"
  location = local.location
  tags     = local.tags
}

resource "azurerm_resource_group_policy_assignment" "require_costcenter" {
  name                 = "require-costcenter"
  display_name         = "Require CostCenter Tag"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = data.azurerm_policy_definition.require_costcenter.id
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Locations: East US, East US 2"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  parameters = jsonencode({
    "listOfAllowedLocations" = {
      "value" = ["eastus", "eastus2"]
    }
  })
}

# ---------- Subnets added to the Lab 02 prod VNet ----------
resource "azurerm_subnet" "compute" {
  name                 = "subnet-compute"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = data.azurerm_virtual_network.prod.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "batch" {
  name                 = "subnet-batch"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = data.azurerm_virtual_network.prod.name
  address_prefixes     = ["10.1.3.0/24"]

  delegation {
    name = "aci"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Standard load balancers are closed by default, so the subnet needs an NSG.
# Rules are separate resources so Lab 04 can add more without fighting this block.
resource "azurerm_network_security_group" "prod_compute" {
  name                = "nsg-prod-compute"
  resource_group_name = data.azurerm_resource_group.network.name
  location            = local.location
  tags                = local.tags
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-http-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.prod_compute.name
}

resource "azurerm_subnet_network_security_group_association" "prod_compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.prod_compute.id
}

# ---------- Load balancer in front of the API ----------
resource "azurerm_public_ip" "api" {
  name                = "pip-dashboard-api"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_lb" "api" {
  name                = "lb-dashboard-api"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.api.id
  }
}

resource "azurerm_lb_backend_address_pool" "api" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.api.id
}

resource "azurerm_lb_probe" "http" {
  name            = "probe-http"
  loadbalancer_id = azurerm_lb.api.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.api.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api.id]
  probe_id                       = azurerm_lb_probe.http.id
}

# ---------- Scale set ----------
resource "azurerm_linux_virtual_machine_scale_set" "dashboard_api" {
  name                = "vmss-dashboard-api"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  sku                 = "Standard_D2nlds_v6"
  instances           = 2
  zones               = ["1", "2", "3"]
  admin_username      = "solsticeadmin"
  tags                = local.tags

  admin_ssh_key {
    username   = "solsticeadmin"
    public_key = file(pathexpand(var.ssh_public_key_path))
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

  # Bootstrap: web server for the LB probe, plus stress-ng for the autoscale test
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - nginx
      - stress-ng
    runcmd:
      - echo "Solstice dashboard API - served by $(hostname)" > /var/www/html/index.html
  CLOUDINIT
  )

  network_interface {
    name    = "nic-dashboard-api"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.compute.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.api.id]
    }
  }

  depends_on = [azurerm_subnet_network_security_group_association.prod_compute]
}

resource "azurerm_monitor_autoscale_setting" "dashboard_api" {
  name                = "autoscale-dashboard-api"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.dashboard_api.id
  tags                = local.tags

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.dashboard_api.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.dashboard_api.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

# ---------- Container registry + batch job ----------
resource "azurerm_container_registry" "solstice" {
  name                = "crsolstice${var.name_suffix}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = true # documented compromise, see Known Limitations
  tags                = local.tags
}

# The job reaches storage as this identity, not with account keys
resource "azurerm_user_assigned_identity" "batch" {
  name                = "id-solstice-batch"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "batch_read_raw" {
  scope                = local.raw_container_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.batch.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "batch_write_processed" {
  scope                = local.processed_container_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.batch.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_group" "batch_processor" {
  count               = var.deploy_batch_job ? 1 : 0
  name                = "aci-batch-processor"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  os_type             = "Linux"
  restart_policy      = "Never"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.batch.id]
  tags                = local.tags

  exposed_port {
    port     = 80
    protocol = "TCP"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.batch.id]
  }

  image_registry_credential {
    server   = azurerm_container_registry.solstice.login_server
    username = azurerm_container_registry.solstice.admin_username
    password = azurerm_container_registry.solstice.admin_password
  }

  container {
    name   = "batch-processor"
    image  = "${azurerm_container_registry.solstice.login_server}/batch-processor:v1"
    cpu    = 0.5
    memory = 1

    ports {
      port     = 80
      protocol = "TCP"
    }
    environment_variables = {
      AZURE_CLIENT_ID     = azurerm_user_assigned_identity.batch.client_id
      STORAGE_ACCOUNT_URL = "https://${data.azurerm_storage_account.solstice.name}.blob.core.windows.net"
    }
  }

  depends_on = [
    azurerm_role_assignment.batch_read_raw,
    azurerm_role_assignment.batch_write_processed,
  ]
}

# ---------- App Service (the deliberate PaaS comparison) ----------
resource "azurerm_service_plan" "admin" {
  name                = "asp-solstice-admin"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

resource "azurerm_linux_web_app" "admin" {
  name                = "app-solstice-admin-${var.name_suffix}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = local.location
  service_plan_id     = azurerm_service_plan.admin.id
  https_only          = true
  tags                = local.tags

  site_config {}
}