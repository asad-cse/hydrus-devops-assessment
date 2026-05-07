locals {
  name_prefix = "${var.project}-${var.environment}"
  tags        = merge(var.tags, { environment = var.environment })
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "./modules/network"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  tags                = local.tags
}

module "acr" {
  source              = "./modules/acr"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.acr_sku
  tags                = local.tags
}

module "aks" {
  source              = "./modules/aks"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  kubernetes_version  = var.aks_kubernetes_version
  subnet_id           = module.network.aks_subnet_id
  node_count          = var.aks_node_count
  node_vm_size        = var.aks_node_vm_size
  node_min_count      = var.aks_node_min_count
  node_max_count      = var.aks_node_max_count
  acr_id              = module.acr.acr_id
  tags                = local.tags
}
