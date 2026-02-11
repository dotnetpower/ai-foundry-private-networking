variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Jumpbox 배포 리전"
  type        = string
}

variable "jumpbox_subnet_id" {
  description = "Jumpbox 서브넷 ID"
  type        = string
}

variable "bastion_subnet_id" {
  description = "Azure Bastion 서브넷 ID"
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

variable "enable_bastion" {
  description = "Azure Bastion 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_windows_jumpbox" {
  description = "Windows Jumpbox VM 활성화 여부"
  type        = bool
  default     = false
}
