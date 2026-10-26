resource "cloudflare_workers_script" "proxy" {
  account_id         = var.cloudflare_account_id
  script_name        = "miqat-proxy"
  content            = file("${path.module}/worker/proxy.js")
  main_module        = "proxy.js"
  compatibility_date = "2026-10-01"

  bindings = [
    {
      name = "UPSTREAM"
      type = "plain_text"
      text = google_cloud_run_v2_service.server.uri
    },
  ]
}

resource "cloudflare_workers_custom_domain" "server" {
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.domain.id
  hostname   = "miqat.${var.domain}"
  service    = cloudflare_workers_script.proxy.script_name
}
