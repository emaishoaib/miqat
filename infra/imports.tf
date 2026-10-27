import {
  to = google_cloud_run_v2_service.server
  id = "projects/${var.project_id}/locations/${var.region}/services/miqat"
}

import {
  to = google_artifact_registry_repository.images
  id = "projects/${var.project_id}/locations/${var.region}/repositories/cloud-run-source-deploy"
}

import {
  to = neon_project.database
  id = var.neon_project_id
}

import {
  to = cloudflare_zone.domain
  id = var.cloudflare_zone_id
}

import {
  to = google_apikeys_key.maps
  id = "projects/${var.project_id}/locations/global/keys/${var.maps_api_key_id}"
}
