variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "name_suffix" {
  type        = string
  description = "Same suffix used in Labs 02 and 03"
}

variable "alert_email" {
  type        = string
  description = "Address that receives alert notifications"
}