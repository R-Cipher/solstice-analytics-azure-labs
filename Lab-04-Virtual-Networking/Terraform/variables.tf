variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key installed on the ops VM"
  default     = "~/.ssh/id_rsa.pub"
}