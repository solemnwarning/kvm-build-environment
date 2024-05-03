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

  provisioner "file" {
    sources = [
      "buildkite-agent.cfg",
      "buildkite-agent.gitconfig",
      "buildkite-agent.known_hosts",
      "buildkite-environment-hook",
      "powernapd.conf",
    ]

    destination = "/tmp/"
  }

  provisioner "shell" {
    environment_vars = [
      "http_proxy=${var.http_proxy}",
      "https_proxy=${var.https_proxy}",

      "DEBIAN_FRONTEND=noninteractive",
    ]

    inline = [
      # Install Buildkite agent

      "apt-get -y update",
      "apt-get -y install apt-transport-https dirmngr wget gpg gpg-agent",
      "https_proxy=\"${var.https_proxy}\" wget -O - https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | gpg --dearmor -o /etc/apt/trusted.gpg.d/buildkite-agent-keyring.gpg",
      "echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list",

      "apt-get -y update",
      "apt-get -y install buildkite-agent",

      "install -m 0755 -o root -g root /tmp/buildkite-environment-hook /etc/buildkite-agent/hooks/environment",
      "install -m 0644 -o root -g root /tmp/buildkite-agent.cfg        /etc/buildkite-agent/buildkite-agent.cfg",
      "install -m 0644                 /tmp/buildkite-agent.gitconfig  /var/lib/buildkite-agent/.gitconfig",

      "systemctl enable buildkite-agent.service",

      "mkdir /var/lib/buildkite-agent/.ssh/",
      "install -m 0600 /tmp/buildkite-agent.known_hosts /var/lib/buildkite-agent/.ssh/known_hosts",
      "chown -R buildkite-agent:buildkite-agent /var/lib/buildkite-agent/.ssh/",

      # Install build tools

      "apt-get -y update",
      "apt-get -y install build-essential dpkg-dev sbuild schroot debootstrap git-buildpackage debhelper dh-lua dh-python gem2deb python3-setuptools",

      "sbuild-adduser buildkite-agent",

      "rm -f /etc/apt/apt.conf.d/proxy.conf",

      # Use tmpfs for schroot overlays (build stuff in tmpfs)
      "echo 'none  /var/lib/schroot/union/overlay  tmpfs  size=75%  0  0' >> /etc/fstab",

      # Install powernap

      "https_proxy=\"${var.https_proxy}\" wget -O /etc/apt/trusted.gpg.d/solemnwarning-archive-keyring.gpg https://repos.solemnwarning.net/debian/solemnwarning-archive-keyring.gpg",
      "echo deb http://repos.solemnwarning.net/debian/ bookworm main > /etc/apt/sources.list.d/solemnwarning.list",

      "apt-get -y update",
      "apt-get -y install powernap-git",

      "cp /tmp/powernapd.conf /etc/powernap/powernapd.conf",
      "systemctl enable powernap",
    ]
  }

  provisioner "shell" {
    script = "build-chroots.pl"
    environment_vars = [
      "http_proxy=${var.http_proxy}",
      "https_proxy=${var.https_proxy}",
    ]
  }

  provisioner "shell" {
    script = "clean-system.sh"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum debian-build-agent.qcow2 > SHA256SUMS",
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

  cpus        = 4
  memory      = 4096
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
  vm_name          = "debian-build-agent.qcow2"
}
