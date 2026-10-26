variable "project_id" {
  description = "The Google Cloud project that runs Miqat."
  type        = string
}

variable "region" {
  description = "The Google Cloud region for the server."
  type        = string
  default     = "europe-central2"
}
