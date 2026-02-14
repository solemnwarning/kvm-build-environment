packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }

    sshkey = {
      source = "github.com/ivoronin/sshkey"
      version = ">= 1.1.0"
    }
  }
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "http_proxy" {
  default = env("http_proxy")
}

variable "https_proxy" {
  default = env("https_proxy")
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    inline = [
      # Configure the APT proxy for downloading packages.

      "if [ -n \"${var.http_proxy}\" ]; then",
        "echo 'Acquire::http::Proxy \"${var.http_proxy}/\";' >> /etc/apt/apt.conf.d/proxy.conf",
      "fi",

      "if [ -n \"${var.https_proxy}\" ]; then",
        "echo 'Acquire::https::Proxy \"${var.https_proxy}/\";' >> /etc/apt/apt.conf.d/proxy.conf",
      "fi",

      "apt-get -y update",
      "apt-get -y install nginx",

      "rm -f /etc/nginx/sites-enabled/default",
    ]
  }

  provisioner "file" {
    sources = [
      "nginx-server.conf",
    ]

    destination = "/etc/nginx/sites-enabled/ccache-server"
  }

  provisioner "file" {
    sources = [
      "clean-ccache.sh",
    ]

    destination = "/usr/local/bin/clean-ccache"
  }

  provisioner "file" {
    sources = [
      "clean-ccache.service",
      "clean-ccache.timer",
    ]

    destination = "/etc/systemd/system/"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/systemd/system/nginx.service.d/",
    ]
  }

  provisioner "file" {
    sources = [
      "ccache-directory.conf",
    ]

    destination = "/etc/systemd/system/nginx.service.d/"
  }

  provisioner "shell" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable clean-ccache.timer",

      # Enable password-less login on the console.
      "sed -i -e '/# Standard Un\\*x authentication./i # Enable passwordless login on the console\\nauth sufficient pam_securetty.so\\n' /etc/pam.d/login",
      "for i in $(seq 1 6); do echo tty$i; done > /etc/securetty",

      # Restore the normal GRUB timeout for debugging provisioning issues.
      "rm /etc/default/grub.d/15_timeout.cfg",
      "update-grub",
    ]
  }

  provisioner "shell" {
    script = "clean-system.sh"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum ccache-cache-server.qcow2 > SHA256SUMS",
    ]
  }
}

data "sshkey" "install" {}

source qemu "debian" {
  iso_url      = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
  iso_checksum = "file:https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS"
  disk_image   = true

  ssh_private_key_file = data.sshkey.install.private_key_path

  cd_content = {
    "meta-data" = ""
    "user-data" = templatefile("user-data.tpl", { ssh_public_key = data.sshkey.install.public_key })
  }

  cd_label = "cidata"

  # Create a full copy of the base image
  use_backing_file = false

  cpus        = 2
  memory      = 2048
  disk_size   = 24000
  accelerator = "kvm"

  headless = true
  # vnc_bind_address = "0.0.0.0"

  # SSH ports to redirect to the VM being built
  host_port_min = 2222
  host_port_max = 2229

  ssh_username     = "root"
  ssh_wait_timeout = "1000s"

  # Delete and disable root's password to avoid it being used.
  shutdown_command = "passwd -d root && passwd -l root && /sbin/shutdown -hP now"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "ccache-cache-server.qcow2"
}
