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
  base_image = "../step-04-install-vs-build-tools/builds/${var.base_image_version}/step-04-install-vs-build-tools.qcow2"
  base_image_checksum = "file:../step-04-install-vs-build-tools/builds/${var.base_image_version}/SHA256SUMS"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type    = string
  default = "step-05-install-msys2.qcow2"
}

build {
  sources = ["source.qemu.step-05-install-msys2"]

  # Install MSYS/MinGW and any required packages.
  # Based on Docker installation instructions from https://www.msys2.org/docs/ci/

  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$ProgressPreference = 'SilentlyContinue';",

      "Invoke-WebRequest -UseBasicParsing -uri 'https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-base-x86_64-latest.sfx.exe' -OutFile msys2.exe",
      ".\\msys2.exe -y -oC:\\",
      "Remove-Item msys2.exe",

      "function msys() { C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; }",
      "msys ' '",
      "msys 'pacman --noconfirm -Syuu'",
      "msys 'pacman --noconfirm -Syuu'",
      "msys 'pacman --noconfirm -S base-devel git p7zip mingw-w64-x86_64-{toolchain,wxWidgets3.2,jansson,capstone,jbigkit,lua,lua-luarocks,libbotan,libunistring}'",

      # Need the "msys" GCC for compiling Template Toolkit...
      "msys 'pacman --noconfirm -S gcc libxcrypt libxcrypt-devel perl-Mozilla-CA'",
      "msys 'PERL_MM_USE_DEFAULT=1 perl -MCPAN -e ''install Template'' '",

      "msys 'pacman --noconfirm -Scc'",

      # "function mingw32() { $env:MSYSTEM = 'MINGW32'; C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; Remove-Item Env:\\MSYSTEM }",
      "function mingw64() { $env:MSYSTEM = 'MINGW64'; C:\\msys64\\usr\\bin\\bash.exe @('-lc') + @Args; Remove-Item Env:\\MSYSTEM }",

      # Work around https://github.com/msys2/MINGW-packages/pull/12002
      "msys 'mkdir -p C:/msys64/mingw{32,64}/lib/luarocks/rocks-5.4/luafilesystem/1.8.0-1/{conf,lib}'",
      "mingw64 'luarocks install --force luafilesystem'",

      "mingw64 'luarocks install busted'",
    ]

    timeout = "1h"
  }

  provisioner "powershell" {
    script = "../packer-Win2022/scripts/cleanup.ps1"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}

source qemu "step-05-install-msys2" {
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
  output_directory = "${var.output_dir}"
  vm_name          = "${var.output_name}"
}
