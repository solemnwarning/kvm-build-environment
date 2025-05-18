packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "base_image_version" {
  type    = string
}

locals {
  base_image = "../step-03-windows-update/builds/${var.base_image_version}/step-03-windows-update.qcow2"
  base_image_checksum = "file:../step-03-windows-update/builds/${var.base_image_version}/SHA256SUMS"
}

variable "vs_build_tools" {
  type    = string
  default = "../step-02-download-vs-build-tools/builds/latest/vs-build-tools.qcow2"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type = string
  default = "step-04-install-vs-build-tools.qcow2"
}

build {
  sources = ["source.qemu.step-04-install-vs-build-tools"]

  # Install the Visual Studio Build Tools.

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      # The drive with the Visual Studio Build Tools installer previously prepared by
      # msvc-build-tools.pkr.hcl isn't initially "Online" under Windows server, so we enable any
      # offline disks we can find.
      "Get-Disk |",
      "  Where IsOffline -eq $True |",
      "  Set-Disk -IsOffline $False",

      "$vs_tools_drive = Get-Volume -FileSystemLabel 'Visual Studio Build Tools'",
      "$vs_tools_drive = $vs_tools_drive.DriveLetter",

      "$p = Start-Process \"$${vs_tools_drive}:\\vs_buildtools.exe\" -ArgumentList '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended;includeOptional' -Wait -PassThru",
      "if($p.ExitCode -ne 0) { throw \"vs_buildtools.exe failed (exit code $($p.ExitCode.ToString()))\" }",
    ]

    timeout = "1h"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}

source qemu "step-04-install-vs-build-tools" {
  iso_url      = local.base_image
  iso_checksum = local.base_image_checksum
  disk_image   = true

  # Create a thin copy of the base image since we're just the input to another pipeline step anyway.
  use_backing_file = true

  cpus        = 4
  memory      = 4096
  disk_size   = "120G"
  accelerator = "kvm"

  qemuargs = [
    [ "-drive", "file=${var.output_dir}/${var.output_name},if=virtio,cache=unsafe,discard=unmap,format=qcow2,detect-zeroes=unmap" ],
    [ "-drive", "file=${var.vs_build_tools},if=virtio,format=qcow2,readonly" ],
  ]

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
