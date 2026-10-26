output "server_url" {
  description = "The address Cloud Run serves the server at."
  value       = google_cloud_run_v2_service.server.uri
}

output "project_id" {
  description = "The Google Cloud project that runs Miqat."
  value       = var.project_id
}

output "region" {
  description = "The Google Cloud region for the server."
  value       = var.region
}

output "image_repository" {
  description = "Where the server's images are stored."
  value       = google_artifact_registry_repository.images.registry_uri
}

output "public_url" {
  description = "The address the apps use to reach the server."
  value       = "https://${cloudflare_workers_custom_domain.server.hostname}"
}
