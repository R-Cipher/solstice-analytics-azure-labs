# Azure Provider source and versions
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {
    # Lets terraform destroy remove a vault that still holds backup items
    recovery_service {
      purge_protected_items_from_vault_on_destroy = true
      vm_backup_stop_protection_and_retain_data_on_destroy = false # lab teardown: don't keep VM backup data
    }
  }
  subscription_id = var.subscription_id
}