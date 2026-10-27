locals {
  cloud_build_agent = "service-${data.google_project.this.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud_build_agent" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${local.cloud_build_agent}"
}

resource "google_cloudbuildv2_connection" "github" {
  name     = "github"
  location = var.region

  lifecycle {
    ignore_changes = [github_config]
  }

  depends_on = [google_project_iam_member.cloud_build_agent]
}

resource "google_cloudbuildv2_repository" "miqat" {
  name              = "miqat"
  parent_connection = google_cloudbuildv2_connection.github.id
  remote_uri        = var.github_repository_url
}

resource "google_service_account" "deployer" {
  account_id   = "miqat-deployer"
  display_name = "Miqat deployer"

  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(["roles/logging.logWriter", "roles/run.developer"])
  project  = var.project_id
  role     = each.key
  member   = google_service_account.deployer.member
}

resource "google_artifact_registry_repository_iam_member" "deployer" {
  repository = google_artifact_registry_repository.images.name
  location   = var.region
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.deployer.member
}

resource "google_service_account_iam_member" "deployer" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.default_service_account}"
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

resource "google_cloudbuild_trigger" "deploy" {
  name            = "deploy-server"
  location        = var.region
  filename        = "cloudbuild.yaml"
  included_files  = ["server/**", "cloudbuild.yaml"]
  service_account = google_service_account.deployer.id

  repository_event_config {
    repository = google_cloudbuildv2_repository.miqat.id

    push {
      branch = "^main$"
    }
  }

  depends_on = [
    google_project_iam_member.deployer,
    google_artifact_registry_repository_iam_member.deployer,
    google_service_account_iam_member.deployer,
  ]
}
