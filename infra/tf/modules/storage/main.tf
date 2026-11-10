terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

variable "name" { type = string }
variable "containers" { type = set(string) }
variable "soft_delete_days" {
  type    = number
  default = null
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_storage_account" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = true
  tags                            = var.tags

  dynamic "blob_properties" {
    for_each = var.soft_delete_days == null ? [] : [var.soft_delete_days]
    content {
      delete_retention_policy {
        days = blob_properties.value
      }
      container_delete_retention_policy {
        days = blob_properties.value
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "this" {
  for_each              = var.containers
  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

output "account_id" {
  value = azurerm_storage_account.this.id
}

output "account_name" {
  value = azurerm_storage_account.this.name
}

output "container_ids" {
  value = { for name, container in azurerm_storage_container.this : name => container.resource_manager_id }
}
