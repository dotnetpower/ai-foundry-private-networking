variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "vnet_name" {
  description = "VNet 이름"
  type        = string
}

variable "vnet_address_prefix" {
  description = "VNet 주소 공간"
  type        = string
}

variable "agent_subnet_name" {
  description = "Agent 서브넷 이름"
  type        = string
}

variable "agent_subnet_prefix" {
  description = "Agent 서브넷 주소 범위"
  type        = string
}

variable "pe_subnet_name" {
  description = "Private Endpoint 서브넷 이름"
  type        = string
}

variable "pe_subnet_prefix" {
  description = "Private Endpoint 서브넷 주소 범위"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
}
