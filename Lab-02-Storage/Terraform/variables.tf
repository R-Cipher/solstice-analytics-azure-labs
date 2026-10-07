variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where the resources will be deployed."
}

variable "name_suffix" {
  type        = string
  description = "Short lowercase suffix that makes globally unique names unique (for example your initials plus two digits)"
}

variable "lock_down_public_access" {
  type        = bool
  description = "false = storage account reachable from the internet (used to upload test files). true = storage account only reachable from private endpoints."
  default     = false
}