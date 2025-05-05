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
  hostname = "macos14-build${ var.hostname_suffix }-${ random_id.suffix.hex }"
}

data "local_file" "image_version" {
  filename = "${ path.root }/macos14-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/macos.qcow2"
  opencore_path = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/OpenCore.qcow2"
  vars_path     = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/OVMF_VARS.fd"
}

resource "libvirt_volume" "hdd" {
  name   = "${ local.hostname }.${ var.domain }_hdd.qcow2"
  source = local.image_path
  format = "qcow2"

  # Ensure disk is reset to initial state if cloud-init data is changed.
  lifecycle {
    replace_triggered_by = [
      libvirt_cloudinit_disk.cloud_init.id,
    ]
  }
}

resource "libvirt_volume" "opencore" {
  name   = "${ local.hostname }.${ var.domain }_OpenCore.qcow2"
  source = local.opencore_path
  format = "qcow2"
}

# Upload the UEFI variables file as a raw disk image file.
resource "libvirt_volume" "efi_vars" {
  name   = "${ local.hostname }.${ var.domain }_VARS.fd"
  source = local.vars_path
  format = "raw"
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name   = "${ local.hostname }.${ var.domain }_cloud-init.iso"

  user_data  = templatefile("${ path.module }/macos14-build-agent-deploy.user-data.tftpl", {
    hostname = "${ local.hostname }"
    domain   = "${ var.domain }"

    http_proxy_url        = "${ var.http_proxy_url }"
    admin_username        = "${ var.admin_username }"
    admin_ssh_keys        = "${ var.admin_ssh_keys }"
    buildkite_agent_token = "${ var.buildkite_agent_token }"
  })
}

resource "libvirt_domain" "macos" {
  name    = "${ local.hostname }.${ var.domain }"
  memory  = var.memory
  vcpu    = var.vcpu
  running = false

  # macOS needs very specific configuration which isn't supported by the
  # libvirt Terraform provider, but it does allow us to transform the generated
  # domain XML using XSLT (see macos.domain.xsl for more details).
  xml {
    xslt = file("${ path.module }/macos14-build-agent-deploy.domain.xsl")
  }

  firmware = "/usr/share/OVMF/OVMF_CODE.fd"
  nvram {
    file = "${libvirt_volume.efi_vars.id}"
  }

  network_interface {
    bridge = "dmz-build"
  }

  disk {
    volume_id = "${libvirt_volume.opencore.id}"
  }

  disk {
    volume_id = "${libvirt_volume.hdd.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.cloud_init.id}"
}
