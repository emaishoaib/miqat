locals {
  server_secrets = {
    MIQAT_DATABASE_URL  = "database-url"
    GOOGLE_MAPS_API_KEY = "google-maps-api-key"
    MIQAT_ADMIN_TOKEN   = "admin-token"
  }
}

resource "google_cloud_run_v2_service" "server" {
  name                = "miqat"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = true

  template {
    service_account = local.default_service_account

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.image

      dynamic "env" {
        for_each = local.server_secrets

        content {
          name = env.key

          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.server[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [client, client_version]
  }

  depends_on = [
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_iam_member.server,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.server.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
