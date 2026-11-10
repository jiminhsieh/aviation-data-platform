terraform {
  required_version = "~> 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.41.0"
    }
  }
  backend "local" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

variable "subscription_id" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["sit", "uat", "prod"], var.environment)
    error_message = "Select sit, uat or prod."
  }
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique, 3-24 lower-case letters/digits; never reuse across environments."
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "The storage account name must contain 3-24 lower-case letters/digits."
  }
}

variable "acr_name" {
  type        = string
  description = "Globally unique registry name for this environment."
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name for this environment."
}

variable "address_space" {
  type        = string
  description = "Unique VNet /16 for this environment; adjust subnet CIDRs together if changed."
  default     = "10.42.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.42.0.0/22"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.42.4.0/24"
}

variable "aks_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "opensky_secret_names" {
  type        = set(string)
  description = "Names only, created by the operator after the first apply; never pass secret values to Terraform."
  default     = []
}

locals {
  prefix = "aviation-${var.environment}"
  tags   = { project = "aviation-data-platform", environment = var.environment }
}

resource "azurerm_resource_group" "this" {
  name     = "${local.prefix}-rg"
  location = "southeastasia"
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_subnet" "private" {
  name                 = "private-endpoints-reserved"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_cidr]
}

resource "azurerm_network_security_group" "aks" {
  name                = "${local.prefix}-aks-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_group" "private" {
  name                = "${local.prefix}-private-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

resource "azurerm_storage_account" "this" {
  name                            = var.storage_account_name
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = true
  tags                            = local.tags

  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "this" {
  for_each              = toset(["bronze", "checkpoints", "lakehouse", "quarantine"])
  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                              = "${local.prefix}-aks"
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  dns_prefix                        = "${local.prefix}-aks"
  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "system"
    vm_size        = var.aks_vm_size
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags       = local.tags
  depends_on = [azurerm_subnet_network_security_group_association.aks]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_user_assigned_identity" "collector" {
  name                = "${local.prefix}-collector"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "collector" {
  name                = "collector"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.collector.id
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:ingestion:opensky-collector"
  audience            = ["api://AzureADTokenExchange"]
}

# Read/write/add only: runtime must still enforce conditional create; RBAC alone cannot forbid overwrites.
resource "azurerm_role_definition" "collector_blobs" {
  name              = "${local.prefix}-collector-no-delete"
  scope             = azurerm_resource_group.this.id
  assignable_scopes = [azurerm_resource_group.this.id]

  permissions {
    actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/read"]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action"
    ]
  }
}

resource "azurerm_role_assignment" "collector_blobs" {
  for_each           = toset(["bronze", "quarantine"])
  scope              = azurerm_storage_container.this[each.key].resource_manager_id
  role_definition_id = azurerm_role_definition.collector_blobs.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.collector.principal_id
}

resource "azurerm_key_vault" "this" {
  name                          = var.key_vault_name
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 30
  purge_protection_enabled      = true
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_role_assignment" "collector_secret" {
  for_each             = var.opensky_secret_names
  scope                = "${azurerm_key_vault.this.id}/secrets/${each.key}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.collector.principal_id
}

resource "azurerm_databricks_workspace" "this" {
  name                = "${local.prefix}-dbx"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  tags                = local.tags
}

resource "azurerm_databricks_access_connector" "this" {
  name                = "${local.prefix}-uc"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  identity {
    type = "SystemAssigned"
  }
  tags = local.tags
}

resource "azurerm_role_assignment" "uc_storage" {
  for_each             = toset(["bronze", "checkpoints", "lakehouse"])
  scope                = azurerm_storage_container.this[each.key].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.prefix}-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Categories come from each live service; no hard-coded unsupported log category names.
data "azurerm_monitor_diagnostic_categories" "this" {
  for_each = {
    aks       = azurerm_kubernetes_cluster.this.id
    acr       = azurerm_container_registry.this.id
    vault     = azurerm_key_vault.this.id
    workspace = azurerm_databricks_workspace.this.id
    storage   = "${azurerm_storage_account.this.id}/blobServices/default"
  }
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each                   = data.azurerm_monitor_diagnostic_categories.this
  name                       = "${local.prefix}-diagnostics"
  target_resource_id         = each.value.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = each.value.log_category_types
    content {
      category = enabled_log.value
    }
  }
}

output "workspace_host" {
  value = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_id" {
  value = azurerm_databricks_workspace.this.workspace_id
}

output "access_connector_id" {
  value = azurerm_databricks_access_connector.this.id
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "collector_client_id" {
  value = azurerm_user_assigned_identity.collector.client_id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}
