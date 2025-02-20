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
  hostname = "windows-build${ var.hostname_suffix }-${ random_id.suffix.hex }"
}

data "local_file" "image_version" {
  filename = "${ path.root }/windows-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/windows-build-agent-image/builds/${ local.image_version }/windows-build-agent.qcow2"
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

  # Ensure user_data has DOS line endings for our horrible batch script to be
  # able to parse it correctly.
  user_data  = replace(replace(
    templatefile("${ path.module }/windows-build-agent.user-data.tftpl", {
      hostname = "${ local.hostname }"
      spawn = var.spawn
      git_cache_https_cert = data.terraform_remote_state.build_infrastructure.outputs.git_cache_https_cert
      vcpkg_cache_https_cert = data.terraform_remote_state.build_infrastructure.outputs.vcpkg_cache_https_cert
  }), "\r", ""), "\n", "\r\n")
}

resource "libvirt_domain" "windows_build_agent" {
  name    = "${ local.hostname }.${ var.domain }"
  memory  = var.memory
  vcpu    = var.vcpu
  running = false

  xml {
    xslt = file("${ path.root }/windows-build-agent-deploy/windows-build-agent.domain.xsl")
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
