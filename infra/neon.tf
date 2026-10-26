resource "neon_project" "database" {
  name                      = "miqat"
  history_retention_seconds = 21600

  lifecycle {
    prevent_destroy = true
  }
}
