resource "google_project_service" "enabled" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "geocoding-backend.googleapis.com",
    "places.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "timezone-backend.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

data "google_project" "this" {}

locals {
  default_service_account = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "builder" {
  project = var.project_id
  role    = "roles/run.builder"
  member  = "serviceAccount:${local.default_service_account}"
}
