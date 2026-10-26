output "server_url" {
  description = "The address Cloud Run serves the server at."
  value       = google_cloud_run_v2_service.server.uri
}
