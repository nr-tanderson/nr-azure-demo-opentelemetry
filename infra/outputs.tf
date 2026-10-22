output "resource_group_name" {
  value = azurerm_resource_group.demo.name
}

output "location" {
  value = var.location
}

output "name_prefix" {
  value = var.name_prefix
}

output "github_actions_principal_object_id" {
  value = var.github_actions_principal_object_id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.demo.name
}
