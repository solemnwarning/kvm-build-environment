packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "base_image_version" {
  type = string
}

locals {
  base_image = "../step-01-windows-base/builds/${var.base_image_version}/step-01-windows-base.qcow2"
  base_image_checksum = "file:../step-01-windows-base/builds/${var.base_image_version}/SHA256SUMS"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type    = string
  default = "step-03-windows-update.qcow2"
}

build {
  sources = ["source.qemu.step-03-windows-update"]

  # Disable automatic updates.
  # This is a transient VM image so we don't want to waste bandwidh downloading updates and CPU
  # time installing them when they'll be discarded anyway.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Set-ItemProperty -Path \"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU\" -Name NoAutoUpdate -Value 1",
    ]
  }

  provisioner "powershell" {
    script = "../packer-Win2022/scripts/win-update.ps1"
  }

  provisioner "windows-restart" {}

  provisioner "powershell" {
    script = "../packer-Win2022/scripts/win-update.ps1"
  }

  provisioner "windows-restart" {}

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}

source qemu "step-03-windows-update" {
  iso_url      = local.base_image
  iso_checksum = local.base_image_checksum
  disk_image   = true

  # Create a thin copy of the base image since we're just the input to another pipeline step anyway.
  use_backing_file = true

  cpus        = 4
  memory      = 4096
  disk_size   = "120G"
  accelerator = "kvm"

  headless = true
  # vnc_bind_address = "0.0.0.0"

  communicator = "winrm"
  winrm_username = "Administrator"
  winrm_password = "packer"
  winrm_use_ssl = true
  winrm_insecure = true
  winrm_timeout = "4h"

  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout = "30m"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = var.output_dir
  vm_name          = var.output_name
}
