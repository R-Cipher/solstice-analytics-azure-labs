variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "name_suffix" {
  type        = string
  description = "Same suffix used in Lab 02"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key installed on the scale set instances"
  default     = "~/.ssh/id_rsa.pub"
}

variable "deploy_batch_job" {
  type        = bool
  description = "false on the first apply (image does not exist yet), true after the image is pushed to ACR"
  default     = false
}