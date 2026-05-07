variable "project" {
  type        = string
  description = "Project prefix"
  default     = "hydrus"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/stage/prod)"
}

variable "location" {
  type        = string
  default     = "southeastasia"
}

variable "tags" {
  type    = map(string)
  default = {
    project   = "hydrus"
    managedBy = "terraform"
  }
}

# Network
variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

# AKS
variable "aks_kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_node_min_count" {
  type    = number
  default = 1
}

variable "aks_node_max_count" {
  type    = number
  default = 1
}

# ACR
variable "acr_sku" {
  type    = string
  default = "Basic"
}
