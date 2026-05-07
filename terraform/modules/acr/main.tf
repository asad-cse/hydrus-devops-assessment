resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "azurerm_container_registry" "this" {
  # ACR name must be alphanumeric + globally unique
  name                = replace("${var.name_prefix}acr${random_string.suffix.result}", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
