variable "vnet_subnet_id" {
  type        = string
  description = "ID of the subnet the AKS node pool will be deployed into"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where networking resources will be created"
}