terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Storage account containing installation scripts"
  type        = string
}

variable "storage_container_name" {
  description = "Storage container with scripts"
  type        = string
  default     = "scripts"
}

variable "tag_filter" {
  description = "VM tag filter (use 'NONE' for no filtering, or 'key:value' format)"
  type        = string
  default     = "NONE"
}

locals {
  service_name = "trendmicro-agent-service"
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "scripts" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_storage_account" "function_storage" {
  name                     = "${replace(local.service_name, "-", "")}sa"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_plan" {
  name                = "${local.service_name}-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "scan_instances" {
  name                = "${local.service_name}-scan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "STORAGE_ACCOUNT_NAME"           = var.storage_account_name
    "STORAGE_CONTAINER_NAME"         = var.storage_container_name
    "TAG_FILTER"                     = var.tag_filter
    "AZURE_SUBSCRIPTION_ID"          = data.azurerm_client_config.current.subscription_id
    "ENABLE_ORYX_BUILD"              = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_linux_function_app" "install_agent" {
  name                = "${local.service_name}-install"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "STORAGE_ACCOUNT_NAME"           = var.storage_account_name
    "STORAGE_CONTAINER_NAME"         = var.storage_container_name
    "AZURE_SUBSCRIPTION_ID"          = data.azurerm_client_config.current.subscription_id
    "ENABLE_ORYX_BUILD"              = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "scan_reader" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_function_app.scan_instances.identity[0].principal_id
}

resource "azurerm_role_assignment" "scan_vm_contributor" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_linux_function_app.scan_instances.identity[0].principal_id
}

resource "azurerm_role_assignment" "install_reader" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_function_app.install_agent.identity[0].principal_id
}

resource "azurerm_role_assignment" "install_vm_contributor" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_linux_function_app.install_agent.identity[0].principal_id
}

resource "azurerm_role_assignment" "scan_storage_reader" {
  scope                = data.azurerm_storage_account.scripts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.scan_instances.identity[0].principal_id
}

resource "azurerm_role_assignment" "install_storage_reader" {
  scope                = data.azurerm_storage_account.scripts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.install_agent.identity[0].principal_id
}

resource "azurerm_eventgrid_system_topic" "vm_events" {
  name                   = "${local.service_name}-vm-events"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = var.location
  source_arm_resource_id = data.azurerm_resource_group.main.id
  topic_type             = "Microsoft.Resources.ResourceGroups"
}

resource "azurerm_eventgrid_event_subscription" "vm_created" {
  name  = "${local.service_name}-vm-created"
  scope = data.azurerm_resource_group.main.id

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.install_agent.id}/functions/InstallAgent"
  }

  included_event_types = [
    "Microsoft.Resources.ResourceWriteSuccess"
  ]

  subject_filter {
    subject_begins_with = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/virtualMachines/"
  }

  advanced_filter {
    string_in {
      key    = "data.operationName"
      values = ["Microsoft.Compute/virtualMachines/write"]
    }
  }
}

output "scan_function_url" {
  value       = "https://${azurerm_linux_function_app.scan_instances.default_hostname}"
  description = "URL of the scan instances function"
}

output "install_function_url" {
  value       = "https://${azurerm_linux_function_app.install_agent.default_hostname}"
  description = "URL of the install agent function"
}

output "scan_function_identity" {
  value       = azurerm_linux_function_app.scan_instances.identity[0].principal_id
  description = "Managed identity of scan function"
}
