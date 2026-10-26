provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_secret_manager_secret_version" "neon_api_key" {
  secret = "neon-api-key"
}

provider "neon" {
  api_key = data.google_secret_manager_secret_version.neon_api_key.secret_data
}

data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}

provider "cloudflare" {
  api_token = data.google_secret_manager_secret_version.cloudflare_api_token.secret_data
}
