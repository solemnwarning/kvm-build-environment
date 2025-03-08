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

variable "bvssh_inst_url" {
  default = "https://dl.bitvise.com/BvSshServer-Inst.exe"
}

variable "winxp_iso_name" {
  default = "en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
}

variable "winxp_iso_url" {
  default = "https://archive.org/download/XPPRO_SP3_ENU/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "file" {
    sources = [
      "buildkite-agent.cfg",
      "buildkite-agent.id_rsa",
      "buildkite-agent.known_hosts",
      "buildkite-environment-hook",
      "buildkite-pre-exit-hook",
      "powernapd.conf",
      "smb.conf",
      "win",
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
      "wget -O - https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | gpg --dearmor -o /etc/apt/trusted.gpg.d/buildkite-agent-keyring.gpg",
      "echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list",

      "apt-get -y update",
      "apt-get -y install buildkite-agent",

      "install -m 0755 -o root -g root /tmp/buildkite-environment-hook /etc/buildkite-agent/hooks/environment",
      "install -m 0755 -o root -g root /tmp/buildkite-pre-exit-hook    /etc/buildkite-agent/hooks/pre-exit",
      "install -m 0644 -o root -g root /tmp/buildkite-agent.cfg        /etc/buildkite-agent/buildkite-agent.cfg",

      "install -m 0755 -o root -g root /tmp/win /usr/local/bin/",

      "systemctl enable buildkite-agent.service",

      "mkdir /var/lib/buildkite-agent/.ssh/",
      "install -m 0600 /tmp/buildkite-agent.known_hosts /var/lib/buildkite-agent/.ssh/known_hosts",
      "install -m 0600 /tmp/buildkite-agent.id_rsa /var/lib/buildkite-agent/.ssh/id_rsa",
      "chown -R buildkite-agent:buildkite-agent /var/lib/buildkite-agent/.ssh/",

      # Install QEMU
      "apt-get -y install --no-install-recommends qemu-system",
      "usermod -a -G kvm buildkite-agent",

      # Install powernap

      "wget -O /etc/apt/trusted.gpg.d/solemnwarning-archive-keyring.gpg https://repos.solemnwarning.net/debian/solemnwarning-archive-keyring.gpg",
      "echo deb http://repos.solemnwarning.net/debian/ bookworm main > /etc/apt/sources.list.d/solemnwarning.list",

      "apt-get -y update",
      "apt-get -y install powernap-git",

      "cp /tmp/powernapd.conf /etc/powernap/powernapd.conf",
      "systemctl enable powernap",

      # Install Packer

      "wget -O - https://apt.releases.hashicorp.com/gpg | apt-key add -",
      "echo deb [arch=amd64] https://apt.releases.hashicorp.com bookworm main > /etc/apt/sources.list.d/hashicorp.list",

      "apt-get -y update",
      "apt-get -y install packer",

      # Install Samba

      "apt-get -y install samba",
      "install -m 0644 /tmp/smb.conf /etc/samba/smb.conf",
    ]
  }

  # Build Windows XP VM

  provisioner "shell-local" {
    inline = [
      "if [ ! -e winxp-image/BvSshServer-Inst.exe ]; then wget -O winxp-image/BvSshServer-Inst.exe ${var.bvssh_inst_url}; fi",
      "if [ ! -e winxp-image/${var.winxp_iso_name} ]; then wget -O winxp-image/${var.winxp_iso_name} ${var.winxp_iso_url}; fi",
    ]
  }

  provisioner "file" {
    sources = [
      "winxp-image"
    ]

    destination = "/usr/src/"
  }

  provisioner "shell" {
    inline = [
      "cd /usr/src/winxp-image/",
      "packer init  -var iso_url=${var.winxp_iso_name} winxp.pkr.hcl",
      "packer build -var iso_url=${var.winxp_iso_name} winxp.pkr.hcl",

      "mkdir /opt/winxp-image/",
      "cp /usr/src/winxp-image/output/winxp.qcow2 /opt/winxp-image/",

      "rm -rf /usr/src/winxp-image/",
    ]
  }

  provisioner "shell" {
    script = "clean-system.sh"
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum winxp-test-agent.qcow2 > SHA256SUMS",
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
  cpu_model   = "host"
  memory      = 2048
  disk_size   = 20000
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
  vm_name          = "winxp-test-agent.qcow2"
}
