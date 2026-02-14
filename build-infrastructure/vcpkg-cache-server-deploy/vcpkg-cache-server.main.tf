terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
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

resource "tls_self_signed_cert" "https_cert" {
  private_key_pem = tls_private_key.https_key.private_key_pem

  subject {
    common_name = "${ var.hostname }.${ var.domain }"
  }

  dns_names = [
    "${ var.hostname }.${ var.domain }"
  ]

  validity_period_hours = 17520  # 2 years
  early_renewal_hours   = 4380   # 6 months

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

output https_cert {
  value     = tls_self_signed_cert.https_cert.cert_pem
  sensitive = false
}

data "local_file" "image_version" {
  filename = "${ path.root }/vcpkg-cache-server-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
}

resource "libvirt_volume" "root" {
  name   = "${ var.hostname }.${ var.domain }_root.qcow2"
  pool   = var.storage_pool
  source = "${ path.root }/vcpkg-cache-server-image/builds/${ local.image_version }/vcpkg-cache-server.qcow2"
  format = "qcow2"

  # Ensure disk is reset to initial state if cloud-init data is changed.
  lifecycle {
    replace_triggered_by = [
      libvirt_cloudinit_disk.cloud_init.id,
    ]
  }
}

resource "libvirt_volume" "data" {
  name   = "${ var.hostname }.${ var.domain }_data.qcow2"
  pool   = var.storage_pool
  size   = 51539607552 # 48 GiB
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${ var.hostname }.${ var.domain }_cloud-init.iso"
  pool = var.storage_pool

  network_config = templatefile("${ path.module }/vcpkg-cache-server.network-config.tftpl", {
    hostname = var.hostname
    domain   = var.domain

    ip_and_prefix = var.ip_and_prefix
    gateway = var.gateway
    dns_server = var.dns_server
  })

  user_data  = templatefile("${ path.module }/vcpkg-cache-server.user-data.tftpl", {
    hostname = var.hostname
    domain   = var.domain

    admin_ssh_keys = var.admin_ssh_keys

    https_cert = tls_self_signed_cert.https_cert
    https_key  = tls_private_key.https_key

    ssh_host_ecdsa   = tls_private_key.ssh_host_ecdsa
    ssh_host_ed25519 = tls_private_key.ssh_host_ed25519
    ssh_host_rsa     = tls_private_key.ssh_host_rsa
  })
}

resource "libvirt_domain" "domain" {
  name    = "${ var.hostname }.${ var.domain }"
  memory  = "2048"
  vcpu    = 2

  running   = true
  autostart = true

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

  disk {
    volume_id = "${libvirt_volume.data.id}"
  }
}
