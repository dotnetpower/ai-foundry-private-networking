variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "vnet_address_space" {
  description = "VNet 주소 공간"
  type        = list(string)
}

variable "subnet_config" {
  description = "서브넷 구성"
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = list(string)
  }))
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
