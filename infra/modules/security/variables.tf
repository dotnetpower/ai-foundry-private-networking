variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "create_private_dns_zone" {
  description = "Whether to create Private DNS Zone or use existing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
