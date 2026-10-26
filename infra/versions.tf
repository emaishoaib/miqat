terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    neon = {
      source  = "kislerdm/neon"
      version = ">= 0.6"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0"
    }
  }

  backend "gcs" {
    prefix = "miqat"
  }
}
