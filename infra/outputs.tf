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

output "lab_connection" {
  value = {
    resource_group = azurerm_resource_group.demo.name
    cluster        = azurerm_kubernetes_cluster.demo.name
    generation     = random_uuid.generation.result
    registry       = data.azurerm_container_registry.lab.name
    registry_url   = data.azurerm_container_registry.lab.login_server
    state          = "active"
  }
}
