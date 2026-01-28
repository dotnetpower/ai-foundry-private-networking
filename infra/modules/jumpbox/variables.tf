variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "subnet_id" {
  description = "Jumpbox 서브넷 ID"
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
