resource "vault_mount" "pki" {
  path        = "${var.pki_path}"
  type        = "pki"
  description = "Vault TLS Authority"

  default_lease_ttl_seconds = "${var.pki_ttl}"
  max_lease_ttl_seconds     = "${var.pki_max_ttl}"
}

locals {
  ca_endpoints       = "${jsonencode(sort(formatlist("%s/%s/ca", var.vault_base_url, vault_mount.pki.path)))}"
  ca_chain_endpoints = "${jsonencode(sort(formatlist("%s/%s/ca_chain", var.vault_base_url, vault_mount.pki.path)))}"

  crl_distribution_points = "${jsonencode(sort(formatlist("%s/%s/crl", var.vault_base_url, vault_mount.pki.path)))}"
}

resource "vault_generic_secret" "pki_config" {
  path = "${vault_mount.pki.path}/config/urls"

  data_json = <<EOF
{
  "issuing_certificates": ${local.ca_endpoints},
  "crl_distribution_points": ${local.crl_distribution_points},
  "ocsp_servers": []
}
EOF
}

data "template_file" "ca" {
  template = "${file("${path.module}/templates/ca.json")}"

  vars {
    ca                   = "${jsonencode(var.ca_cn)}"
    ca_san               = "${jsonencode(var.ca_san)}"
    ca_ip_san            = "${jsonencode(var.ca_ip_san)}"
    ttl                  = "${var.pki_max_ttl}"
    exclude_cn_from_sans = "${jsonencode(var.ca_exclude_cn_from_sans)}"

    ou             = "${jsonencode(var.ou)}"
    organization   = "${jsonencode(var.organization)}"
    country        = "${jsonencode(var.country)}"
    locality       = "${jsonencode(var.locality)}"
    province       = "${jsonencode(var.province)}"
    street_address = "${jsonencode(var.street_address)}"
    postal_code    = "${jsonencode(var.postal_code)}"
  }
}

resource "vault_generic_secret" "pki_ca" {
  path         = "${vault_mount.pki.path}/root/generate/internal"
  disable_read = true
  data_json    = "${data.template_file.ca.rendered}"

  lifecycle {
    # This is a hack. Reconfiguring this will overwrite the CA
    ignore_changes = ["*"]
  }
}