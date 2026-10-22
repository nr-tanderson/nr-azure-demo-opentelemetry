terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  resource_group_name = "rg-${var.name_prefix}"
  resource_tags = {
    OWNER      = "TANDERSON"
    PROJECT    = "nr-azure-demo-opentelemetry"
    MANAGED_BY = "Terraform"
  }
}

resource "azurerm_resource_group" "demo" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.resource_tags
}

resource "azurerm_kubernetes_cluster" "demo" {
  name                   = "${var.name_prefix}-aks"
  location               = azurerm_resource_group.demo.location
  resource_group_name    = azurerm_resource_group.demo.name
  dns_prefix             = "${var.name_prefix}-${random_id.suffix.hex}"
  sku_tier               = "Free"
  local_account_disabled = true
  tags                   = local.resource_tags

  default_node_pool {
    name                        = "system"
    node_count                  = var.node_count
    vm_size                     = var.node_vm_size
    os_disk_size_gb             = 64
    type                        = "VirtualMachineScaleSets"
    temporary_name_for_rotation = "systemtmp"
    tags                        = local.resource_tags
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

}

resource "azurerm_role_assignment" "github_aks_admin" {
  scope                = azurerm_kubernetes_cluster.demo.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.github_actions_principal_object_id
  principal_type       = "ServicePrincipal"
}