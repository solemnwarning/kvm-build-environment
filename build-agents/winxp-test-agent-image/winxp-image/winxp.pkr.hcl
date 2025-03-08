packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://archive.org/download/XPPRO_SP3_ENU/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
}

variable "iso_checksum" {
  type    = string
  default = "FD8C8D42C1581E8767217FE800BFC0D5649C0AD20D754C927D6C763E446D1927"
}

variable "output_directory" {
  type    = string
  default = "output"
}

source "qemu" "winxp" {
  accelerator    = "kvm"
  net_device     = "rtl8139"
  memory         = 128
  disk_interface = "ide"
  disk_size      = "16G"

  headless         = true
  # vnc_bind_address = "0.0.0.0"

  iso_url      = "${var.iso_url}"
  iso_checksum = "${var.iso_checksum}"

  floppy_files = [
    "WINNT.SIF",
  ]

  cd_files = [
    "BvSshServer-Inst.exe",
    "BssSettings",
    "Keypair_Bv.bkp",
  ]

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  communicator = "ssh"
  ssh_username = "Administrator"
  ssh_password = "Administrator"
  ssh_timeout  = "8h"

  shutdown_command  = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""

  format           = "qcow2"
  output_directory = "${var.output_directory}"
  vm_name          = "winxp.qcow2"
}

build {
  sources = ["source.qemu.winxp"]
}
