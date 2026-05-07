output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "acr_name" {
  value = module.acr.name
}

output "kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${module.aks.cluster_name} --overwrite-existing"
}
