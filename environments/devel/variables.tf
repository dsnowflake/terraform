variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "myapp-dev"
}

variable "challenge_end_date" {
  description = "End date for the challenge in ISO 8601 format"
  type        = string
}