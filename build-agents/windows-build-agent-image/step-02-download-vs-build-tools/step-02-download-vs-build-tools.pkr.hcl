# This is a Packer template which takes a basic Windows image as prepared by
# the packer-Win2022 template and builds a Visual Studio Build Tools installer
# layout on an NTFS-formatted volume for attaching to other images and
# installing the build tools without having to download them every time.

packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "windows_image" {
  type    = string
  default = "../step-01-windows-base/builds/latest/step-01-windows-base.qcow2"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type    = string
  default = "vs-build-tools.qcow2"
}

variable "vs_tools_installer" {
  type    = string
  default = "https://aka.ms/vs/17/release/vs_buildtools.exe"
}

build {
  sources = ["qemu.step-02-download-vs-build-tools"]

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      # Disable automatic updates.
      "Set-ItemProperty -Path \"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU\" -Name NoAutoUpdate -Value 1",

      # Partition and format the second disk as NTFS.
      "Get-Disk |",
      "  Where partitionstyle -eq 'RAW' |",
      "  Initialize-Disk -PartitionStyle MBR -PassThru |",
      "  New-Partition -DriveLetter Z -UseMaximumSize |",
      "  Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Visual Studio Build Tools'",

      # Download the Visual Studio Build Tools bootstrapper.
      "Invoke-WebRequest -UseBasicParsing -uri '${var.vs_tools_installer}' -OutFile 'Z:\\vs_buildtools.exe'",

      # Build a layout with everything we'll be installing on the actual build VM.
      "$p = Start-Process 'Z:\\vs_buildtools.exe' -ArgumentList '--wait', '--quiet', '--layout', 'Z:\\', '--lang', 'en-US', '--add', 'Microsoft.VisualStudio.Workload.VCTools;includeRecommended;includeOptional' -PassThru -Wait",
      "if($p.ExitCode -ne 0) { Write-Error -Message \"vs_buildtools.exe failed (exit code $($p.ExitCode.ToString()))\" }",

      # Trim any unused space on the second disk so it compresses nicely.
      "Optimize-Volume -DriveLetter Z -ReTrim -Verbose",
    ]

    timeout = "1h"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      # Delete the Windows disk image and replace it with the secondary disk where we built the
      # Visual Studio Build Tools layout.

      "cd ${var.output_dir}/",
      "rm ${var.output_name}",
      "mv ${var.output_name}-1 ${var.output_name}",
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}

source qemu "step-02-download-vs-build-tools" {
  iso_url      = var.windows_image
  iso_checksum = "none"
  disk_image   = true

  # Create a CoW clone of the base image since we'll be discarding it when we're done anyway.
  use_backing_file = true

  cpus        = 4
  memory      = 4096
  disk_size   = "120G"
  accelerator = "kvm"

  disk_additional_size = [ "20G" ]

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
