variable "environment" {
  description = "Environment name (devel, stage, prod)"
  type        = string
}
#test
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "myapp"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "access_logging_enabled" {
  description = "Enable access logging"
  type        = bool
  default     = true
}

variable "challenge_end_date" {
  description = "End date for the challenge in ISO 8601 format"
  type        = string
}
