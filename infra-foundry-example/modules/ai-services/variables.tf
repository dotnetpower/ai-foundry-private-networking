# ============================================================================
# AI Services Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "account_name" {
  description = "Name of the AI Services account"
  type        = string
}

variable "model_name" {
  description = "Name of the model to deploy"
  type        = string
  default     = "gpt-4.1"
}

variable "model_format" {
  description = "Format/provider of the model"
  type        = string
  default     = "OpenAI"
}

variable "model_version" {
  description = "Version of the model"
  type        = string
  default     = "2025-04-14"
}

variable "model_sku_name" {
  description = "SKU name for model deployment"
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Tokens per minute capacity"
  type        = number
  default     = 30
}

variable "agent_subnet_id" {
  description = "ID of the Agent subnet for network injection"
  type        = string
}

variable "enable_network_injection" {
  description = "Enable network injection for agents"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
