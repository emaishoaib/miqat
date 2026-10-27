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

variable "neon_project_id" {
  description = "The ID of the Neon project that holds the database."
  type        = string
}

variable "cloudflare_account_id" {
  description = "The Cloudflare account that holds the domain."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID of the domain."
  type        = string
}

variable "domain" {
  description = "The domain the server is reached through."
  type        = string
}

variable "maps_api_key_id" {
  description = "The ID of the Google Maps API key the server uses."
  type        = string
}
