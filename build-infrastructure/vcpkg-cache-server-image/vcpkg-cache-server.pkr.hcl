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

variable "vcpkg_cache_http_version" {
  default = "83359aca757113b321c33c3e653bcd2528323ee5"
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
      "apt-get -y install apache2 golang-go",

      "useradd -d /srv/vcpkg-cache/ -U -m -k /dev/null -r -s /bin/false vcpkg-cache",
      "GOBIN=/usr/local/bin/ go install github.com/lesomnus/vcpkg-cache-http@${var.vcpkg_cache_http_version}",

      "a2enmod ssl proxy proxy_http",
    ]
  }

  provisioner "file" {
    sources = [
      "vcpkg-cache.service",
    ]

    destination = "/etc/systemd/system/"
  }

  provisioner "file" {
    source = "vcpkg-cache.vhost.conf"
    destination = "/etc/apache2/sites-enabled/vcpkg-cache.conf"
  }

  provisioner "shell" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable vcpkg-cache.service",
    ]
  }

  provisioner "shell" {
    script = "clean-system.sh"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum vcpkg-cache-server.qcow2 > SHA256SUMS",
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

  shutdown_command = "/sbin/shutdown -hP now"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "vcpkg-cache-server.qcow2"
}
