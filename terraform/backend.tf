terraform {
  backend "azurerm" {
    resource_group_name  = "hydrus-devs-rg"
    storage_account_name = "hydrustfstateXXXXX"   # need to tbe change
    container_name       = "tfstate"
    key                  = "hydrus.dev.tfstate"   # Every env has to be different kay
  }
}
