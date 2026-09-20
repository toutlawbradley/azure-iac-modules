variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where database resources will be created"
}

variable "location" {
  type        = string
  description = "Azure region for database resources, independent of other modules due to trial subscription regional restrictions"
  default     = "centralus"
}