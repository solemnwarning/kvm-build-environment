terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

data "terraform_remote_state" "build_infrastructure" {
  backend = "local"

  config = {
    path = "${abspath(path.root)}/../build-infrastructure/terraform.tfstate"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  hostname = "debian-build${ var.hostname_suffix }-${ random_id.suffix.hex }"
}

resource "random_password" "root_password" {
  length = 12
  special = false
}

output root_password {
  value     = random_password.root_password.result
  sensitive = true
}

resource "tls_private_key" "ssh_host_rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_private_key" "ssh_host_ecdsa" {
  algorithm = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_private_key" "ssh_host_ed25519" {
  algorithm = "ED25519"
}

resource "tls_private_key" "https_key" {
  algorithm = "RSA"
  rsa_bits = 3072
}

data "local_file" "image_version" {
  filename = "${ path.root }/debian-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/debian-build-agent-image/builds/${ local.image_version }/debian-build-agent.qcow2"
}

resource "tls_private_key" "ccache_client_key" {
  algorithm = "RSA"
  rsa_bits = 3072
}

resource "tls_cert_request" "ccache_client_csr" {
  private_key_pem = tls_private_key.ccache_client_key.private_key_pem

  subject {
    common_name = "${ local.hostname }.${ var.domain }"
  }
}

resource "tls_locally_signed_cert" "ccache_client_cert" {
  cert_request_pem   = tls_cert_request.ccache_client_csr.cert_request_pem
  ca_cert_pem        = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_auth_ca_cert
  ca_private_key_pem = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_auth_ca_key

  validity_period_hours = 17520  # 2 years
  early_renewal_hours   = 4380   # 6 months

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

resource "libvirt_volume" "root" {
  name   = "${ local.hostname }.${ var.domain }_root.qcow2"
  pool   = var.storage_pool
  source = local.image_path
  format = "qcow2"

  # Ensure disk is reset to initial state if cloud-init data is changed.
  lifecycle {
    replace_triggered_by = [
      libvirt_cloudinit_disk.cloud_init.id,
    ]
  }
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${ local.hostname }.${ var.domain }_cloud-init.iso"
  pool = var.storage_pool

  network_config = templatefile("${ path.module }/debian-build-agent.network-config.tftpl", {})

  user_data  = templatefile("${ path.module }/debian-build-agent.user-data.tftpl", {
    hostname = local.hostname
    domain   = var.domain

    root_password = random_password.root_password

    ssh_host_ecdsa   = tls_private_key.ssh_host_ecdsa
    ssh_host_ed25519 = tls_private_key.ssh_host_ed25519
    ssh_host_rsa     = tls_private_key.ssh_host_rsa

    buildkite_agent_token  = var.buildkite_agent_token
    http_proxy_url         = var.http_proxy_url
    admin_ssh_keys         = var.admin_ssh_keys
    buildkite_user_ssh_key = var.buildkite_user_ssh_key

    ccache_cache_https_cert  = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_cert
    ccache_cache_client_cert = tls_locally_signed_cert.ccache_client_cert.cert_pem
    ccache_cache_client_key  = tls_private_key.ccache_client_key.private_key_pem
  })
}

resource "libvirt_domain" "domain" {
  name = "${ local.hostname }.${ var.domain }"

  memory  = var.memory
  vcpu    = var.vcpu
  running = false

  cpu {
    # Needed for nested virtualisation
    mode = "host-passthrough"
  }

  # Destroy the VM when replacing the disk, otherwise it may be left running
  # and the disk changed out from under it.
  lifecycle {
    replace_triggered_by = [
      libvirt_volume.root.id,
    ]
  }

  cloudinit = "${libvirt_cloudinit_disk.cloud_init.id}"

  network_interface {
    bridge = "dmz-build"
  }

  disk {
    volume_id = "${libvirt_volume.root.id}"
  }
}
