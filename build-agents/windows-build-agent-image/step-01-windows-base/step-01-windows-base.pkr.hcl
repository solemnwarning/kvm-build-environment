packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "120G"
}

variable "iso_url" {
  type    = string
  # https://go.microsoft.com/fwlink/?linkid=2345730
  default = "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
}

variable "iso_checksum" {
  type    = string
  default = "7b052573ba7894c9924e3e87ba732ccd354d18cb75a883efa9b900ea125bfd51"
}

variable "virtio_iso_path" {
  type    = string
  default = "virtio-win-0.1.285.iso"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "output_name" {
  type    = string
  default = "step-01-windows-base.qcow2"
}

source "qemu" "windows" {
  # boot_wait          = "5s"

  machine_type  = "q35"
  cpu_model     = "Haswell"
  cpus          = "4"
  memory        = "4096"

  disk_interface  = "virtio-scsi"
  disk_size       = "${var.disk_size}"

  output_directory  = var.output_dir
  vm_name           = var.output_name
  format            = "qcow2"

  # Builds a compact image
  disk_discard        = "unmap"
  disk_detect_zeroes  = "unmap"
  disk_cache          = "unsafe"

  headless          = true
  # vnc_bind_address  = "0.0.0.0"

  iso_checksum  = "${var.iso_checksum}"
  iso_url       = "${var.iso_url}"
  floppy_files  = [ "autounattend.xml", "winrm.ps1" ]


  # Add the virtio ISO as a second CD drive
  qemuargs           = [[ "-cdrom", "${var.virtio_iso_path}" ]]

  communicator       = "winrm"
  winrm_username     = "Administrator"
  winrm_password     = "packer"
  winrm_use_ssl      = false

  shutdown_command   = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout   = "30m"
}

build {
  sources = [ "source.qemu.windows" ]

  provisioner "powershell" {
    scripts = ["setup.ps1"]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    pause_before = "1m0s"
    scripts      = ["cleanup.ps1"]
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum ${var.output_name} > SHA256SUMS",
    ]
  }
}
