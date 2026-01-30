variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "jumpbox_location" {
  description = "Jumpbox 배포 리전"
  type        = string
  default     = "koreacentral"
}

variable "main_vnet_id" {
  description = "East US Main VNet ID"
  type        = string
}

variable "main_vnet_name" {
  description = "East US Main VNet Name"
  type        = string
}

variable "admin_username" {
  description = "VM 관리자 사용자명"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "VM 관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}

variable "private_dns_zone_ids" {
  description = "Private DNS Zone IDs (networking 모듈에서 전달)"
  type        = map(string)
}
