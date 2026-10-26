import {
  to = google_cloud_run_v2_service.server
  id = "projects/${var.project_id}/locations/${var.region}/services/miqat"
}

import {
  to = google_artifact_registry_repository.images
  id = "projects/${var.project_id}/locations/${var.region}/repositories/cloud-run-source-deploy"
}
