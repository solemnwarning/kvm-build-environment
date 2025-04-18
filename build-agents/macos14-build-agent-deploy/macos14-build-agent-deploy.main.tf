terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://root@vmhost01.lan.solemnwarning.net/system?sshauth=privkey"
}

resource "libvirt_volume" "disk" {
  name   = "${ var.hostname }.${ var.domain }.qcow2"
  source = "../macos14-build-agent-image/output/macos.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "opencore" {
  name   = "${ var.hostname }.${ var.domain }.OpenCore.qcow2"
  source = "../macos14-build-agent-image/output/OpenCore.qcow2"
  format = "qcow2"
}

# Upload the UEFI variables file as a raw disk image file.
resource "libvirt_volume" "efi_vars" {
  name   = "${ var.hostname }.${ var.domain }.VARS.fd"
  source = "../macos14-build-agent-image/output/OVMF_VARS.fd"
  format = "raw"
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${ var.hostname }.${ var.domain }.cloud-init.iso"

  user_data  = templatefile("macos14-build-agent-deploy.user-data.tftpl", {
    hostname = "${ var.hostname }"
    domain   = "${ var.domain }"

    http_proxy_url        = "${ var.http_proxy_url }"
    admin_username        = "${ var.admin_username }"
    admin_ssh_keys        = "${ var.admin_ssh_keys }"
    buildkite_agent_token = "${ var.buildkite_agent_token }"
  })
}

resource "libvirt_domain" "macos" {
  name    = "${ var.hostname }.${ var.domain }"
  memory  = 4096
  vcpu    = 4
  running = false

  # macOS needs very specific configuration which isn't supported by the
  # libvirt Terraform provider, but it does allow us to transform the generated
  # domain XML using XSLT (see macos.domain.xsl for more details).
  xml {
    xslt = file("macos14-build-agent-deploy.domain.xsl")
  }

  firmware = "/usr/share/OVMF/OVMF_CODE.fd"
  nvram {
    file = "${libvirt_volume.efi_vars.id}"
  }

  network_interface {
    # Put your bridge interface name here, or use a different type of network
    # interface (see the documentation for the libvirt Terraform provider) for
    # more information.
    bridge = "dmz-build"
  }

  disk {
    volume_id = "${libvirt_volume.opencore.id}"
  }

  disk {
    volume_id = "${libvirt_volume.disk.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.cloud_init.id}"
}
