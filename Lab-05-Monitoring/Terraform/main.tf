locals {
  location = "eastus"
  tags = {
    CostCenter = "SOL-001"
  }
}

# ---------- Resource group + Lab 01 governance ----------
resource "azurerm_resource_group" "monitoring" {
  name     = "rg-solstice-monitoring"
  location = local.location
  tags     = local.tags
}

resource "azurerm_resource_group_policy_assignment" "require_costcenter" {
  name                 = "require-costcenter"
  display_name         = "Require CostCenter Tag"
  resource_group_id    = azurerm_resource_group.monitoring.id
  policy_definition_id = data.azurerm_policy_definition.require_costcenter.id
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Locations: East US, East US 2"
  resource_group_id    = azurerm_resource_group.monitoring.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  parameters = jsonencode({
    "listOfAllowedLocations" = {
      "value" = ["eastus", "eastus2"]
    }
  })
}

# ---------- Log Analytics ----------
resource "azurerm_log_analytics_workspace" "solstice" {
  name                = "law-solstice"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = local.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Lab 02 storage: blob read/write/delete logs plus transaction metrics
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-storage-blob-to-law"
  target_resource_id         = "${data.azurerm_storage_account.solstice.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.solstice.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }
  enabled_metric {
    category = "Transaction"
  }
}

# Lab 04 ops VM: guest CPU and memory through the Azure Monitor Agent
resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = data.azurerm_virtual_machine.ops.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

resource "azurerm_monitor_data_collection_rule" "ops_perf" {
  name                = "dcr-solstice-ops-perf"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = local.location
  kind                = "Linux"
  tags                = local.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.solstice.id
      name                  = "law"
    }
  }

  data_sources {
    performance_counter {
      name                          = "perf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "Processor(*)\\% Processor Time",
        "Memory(*)\\% Used Memory",
      ]
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["law"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "ops" {
  name                    = "dcra-ops-perf"
  target_resource_id      = data.azurerm_virtual_machine.ops.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.ops_perf.id

  depends_on = [azurerm_virtual_machine_extension.ama]
}

# ---------- Saved KQL queries ----------
resource "azurerm_log_analytics_saved_search" "storage_errors" {
  name                       = "storage-errors-24h"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.solstice.id
  category                   = "Solstice"
  display_name               = "Storage errors and throttling (24h)"
  query                      = <<-KQL
    StorageBlobLogs
    | where TimeGenerated > ago(24h)
    | where StatusCode == 429 or StatusCode >= 500 or StatusText in ("ServerBusy", "ClientThrottlingError", "AuthorizationFailure")
    | summarize Requests = count() by bin(TimeGenerated, 15m), StatusText
    | order by TimeGenerated desc
  KQL
}

resource "azurerm_log_analytics_saved_search" "cpu_vs_storage" {
  name                       = "ops-cpu-vs-storage-errors"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.solstice.id
  category                   = "Solstice"
  display_name               = "Ops VM CPU vs storage errors (24h, 5 min bins)"
  query                      = <<-KQL
    let cpu = Perf
      | where TimeGenerated > ago(24h)
      | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
      | summarize AvgCpu = avg(CounterValue) by bin(TimeGenerated, 5m);
    let storageErrors = StorageBlobLogs
      | where TimeGenerated > ago(24h)
      | where StatusCode >= 400
      | summarize StorageErrors = count() by bin(TimeGenerated, 5m);
    cpu
    | join kind=fullouter storageErrors on TimeGenerated
    | project TimeGenerated = coalesce(TimeGenerated, TimeGenerated1), AvgCpu, StorageErrors
    | order by TimeGenerated desc
  KQL
}

# ---------- Alerting ----------
resource "azurerm_monitor_action_group" "oncall" {
  name                = "ag-solstice-oncall"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "solsticeoc"
  tags                = local.tags

  email_receiver {
    name          = "primary-oncall"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "vmss_cpu_high" {
  name                = "alert-vmss-cpu-high"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [data.azurerm_virtual_machine_scale_set.dashboard_api.id]
  description         = "Dashboard API scale set average CPU above 85% for 15 minutes"
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "alert-storage-availability"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [data.azurerm_storage_account.solstice.id]
  description         = "Storage account availability below 99.9%"
  severity            = 1
  window_size         = "PT5M"
  frequency           = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99.9
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

# Closes the loop with Lab 01: tell someone if the core resource group lock is removed
resource "azurerm_monitor_activity_log_alert" "lock_deleted" {
  name                = "alert-lock-deleted"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = "global"
  scopes              = [data.azurerm_subscription.current.id]
  description         = "A resource lock was deleted in the subscription"
  tags                = local.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/locks/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

# ---------- Backup ----------
resource "azurerm_recovery_services_vault" "solstice" {
  name                = "rsv-solstice"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = local.location
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant" # lab cost choice; production would use GeoRedundant
  tags                = local.tags
}

resource "azurerm_backup_policy_vm" "daily_30day" {
  name                = "policy-daily-30day"
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.solstice.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }
}

resource "azurerm_backup_protected_vm" "ops" {
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.solstice.name
  source_vm_id        = data.azurerm_virtual_machine.ops.id
  backup_policy_id    = azurerm_backup_policy_vm.daily_30day.id
}