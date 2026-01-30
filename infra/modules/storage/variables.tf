variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "storage_account_name" {
  description = "Storage Account 이름"
  type        = string
}

variable "subnet_id" {
  description = "서브넷 ID"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID (DNS Zone VNet 링크용)"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS Zone ID 맵"
  type        = map(string)
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
