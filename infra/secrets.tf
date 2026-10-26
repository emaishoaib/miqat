resource "google_secret_manager_secret" "server" {
  for_each  = toset(["database-url", "google-maps-api-key", "admin-token"])
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_iam_member" "server" {
  for_each  = google_secret_manager_secret.server
  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.default_service_account}"
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.server["database-url"].id
  secret_data = neon_project.database.connection_uri_pooler
}
