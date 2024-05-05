terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  hostname = "ipxwrapper-test-${ random_id.suffix.hex }"
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
  filename = "${ path.root }/ipxwrapper-test-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/ipxwrapper-test-agent-image/builds/${ local.image_version }/ipxwrapper-test-agent.qcow2"
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

  network_config = templatefile("${ path.module }/ipxwrapper-test-agent.network-config.tftpl", {})

  user_data  = templatefile("${ path.module }/ipxwrapper-test-agent.user-data.tftpl", {
    hostname = local.hostname
    domain   = var.domain

    root_password = random_password.root_password

    ssh_host_ecdsa   = tls_private_key.ssh_host_ecdsa
    ssh_host_ed25519 = tls_private_key.ssh_host_ed25519
    ssh_host_rsa     = tls_private_key.ssh_host_rsa

    buildkite_agent_token = var.buildkite_agent_token
    http_proxy_url        = var.http_proxy_url
    admin_ssh_keys        = var.admin_ssh_keys
  })
}

resource "libvirt_domain" "domain" {
  name = "${ local.hostname }.${ var.domain }"

  memory  = "16384"
  vcpu    = 8
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
