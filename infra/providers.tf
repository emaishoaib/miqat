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
