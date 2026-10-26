resource "google_artifact_registry_repository" "images" {
  repository_id = "cloud-run-source-deploy"
  location      = var.region
  format        = "DOCKER"
  description   = "Cloud Run Source Deployments"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 2
    }
  }

  cleanup_policies {
    id     = "delete-older"
    action = "DELETE"

    condition {
      older_than = "86400s"
    }
  }

  depends_on = [google_project_service.enabled]
}
