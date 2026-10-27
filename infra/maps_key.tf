resource "google_apikeys_key" "maps" {
  name         = var.maps_api_key_id
  display_name = "Miqat API Key"

  restrictions {
    dynamic "api_targets" {
      for_each = local.maps_apis
      content {
        service = api_targets.value
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.enabled]
}
