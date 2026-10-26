variable "project_id" {
  description = "The Google Cloud project that runs Miqat."
  type        = string
}

variable "region" {
  description = "The Google Cloud region for the server."
  type        = string
  default     = "europe-central2"
}

variable "image" {
  description = "The container image the server runs."
  type        = string
}
