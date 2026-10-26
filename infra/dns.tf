resource "cloudflare_zone" "domain" {
  name = var.domain

  account = {
    id = var.cloudflare_account_id
  }

  lifecycle {
    prevent_destroy = true
  }
}
