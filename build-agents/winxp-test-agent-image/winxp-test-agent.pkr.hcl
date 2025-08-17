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
      "buildkite-agent.id_rsa",
      "buildkite-agent.known_hosts",
      "buildkite-agent.sudoers",
      "buildkite-environment-hook",
      "buildkite-pre-exit-hook",
      "powernapd.conf",
      "smb.conf",
      "win",
      "win-boot",
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
      # Disable use of systemd-resolved so that resolution of .local names from
      # my LAN DNS server works.
      "echo 'hosts: files myhostname dns' >> /etc/nsswitch.conf",

      # Partition disk and create btrfs filesystem for storing images
      "apt-get -y update",
      "apt-get -y install parted btrfs-progs",

      "echo Partitioning disk...",

      "parted -s -a optimal /dev/vdb mklabel gpt",
      "parted -s -a optimal /dev/vdb mkpart primary btrfs 0% 100%",
      "blockdev --rereadpt /dev/vdb",

      "mkfs.btrfs -L srv /dev/vdb1",

      "echo LABEL=srv  /srv/  auto  defaults  0  0 >> /etc/fstab",

      "mount /srv/",

      # Install Buildkite agent

      "apt-get -y update",
      "apt-get -y install apt-transport-https dirmngr wget gpg gpg-agent",
      "wget -O - https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | gpg --dearmor -o /etc/apt/trusted.gpg.d/buildkite-agent-keyring.gpg",
      "echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list",

      "apt-get -y update",
      "apt-get -y install buildkite-agent jq",

      "install -m 0644 -o root -g root /tmp/buildkite-agent.sudoers /etc/sudoers.d/buildkite-agent",

      "install -m 0755 -o root -g root /tmp/buildkite-environment-hook /etc/buildkite-agent/hooks/environment",
      "install -m 0755 -o root -g root /tmp/buildkite-pre-exit-hook    /etc/buildkite-agent/hooks/pre-exit",
      "install -m 0644 -o root -g root /tmp/buildkite-agent.cfg        /etc/buildkite-agent/buildkite-agent.cfg",

      "install -m 0755 -o root -g root /tmp/win /usr/local/bin/",
      "install -m 0755 -o root -g root /tmp/win-boot /usr/local/bin/",

      "systemctl enable buildkite-agent.service",

      "mkdir /var/lib/buildkite-agent/.ssh/",
      "install -m 0600 /tmp/buildkite-agent.known_hosts /var/lib/buildkite-agent/.ssh/known_hosts",
      "install -m 0600 /tmp/buildkite-agent.id_rsa /var/lib/buildkite-agent/.ssh/id_rsa",
      "chown -R buildkite-agent:buildkite-agent /var/lib/buildkite-agent/.ssh/",

      # Install powernap

      "wget -O /etc/apt/trusted.gpg.d/solemnwarning-archive-keyring.gpg https://repos.solemnwarning.net/debian/solemnwarning-archive-keyring.gpg",
      "echo deb http://repos.solemnwarning.net/debian/ bookworm main > /etc/apt/sources.list.d/solemnwarning.list",

      "apt-get -y update",
      "apt-get -y install powernap-git",

      "cp /tmp/powernapd.conf /etc/powernap/powernapd.conf",
      "systemctl enable powernap",

      # Install iSCSI target daemon

      "apt-get -y install tgt",
      "mkdir /srv/iscsi",

      # Install TFTP server and iPXE image.

      "apt-get -y install tftpd-hpa",
      "wget -O /srv/tftp/undionly.kpxe http://boot.ipxe.org/undionly.kpxe",

      # Install Samba

      "apt-get -y install samba",
      "install -m 0644 /tmp/smb.conf /etc/samba/smb.conf",
    ]
  }

  provisioner "file" {
    sources = [
      "images/winxp-base.img.gz",
    ]

    destination = "/srv/iscsi/"
  }

  provisioner "shell" {
    inline = [
      "cd /srv/iscsi/",
      "gunzip *.gz",
    ]
  }

  provisioner "shell" {
    inline = [
      # Clear cloud-init's instance state so per-instance steps (e.g. creating SSH
      # keys, setting passwords) will run when the image is booted.
      "cloud-init clean",
    ]
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",

      "mv winxp-test-agent.qcow2 winxp-test-agent-1.qcow2",
      "mv winxp-test-agent.qcow2-1 winxp-test-agent-2.qcow2",

      # Clear any state from the machine image (logs, caches, keys, etc).
      "virt-sysprep -a winxp-test-agent-1.qcow2 --run-command 'fstrim --all --verbose'",

      # Work around https://bugzilla.redhat.com/show_bug.cgi?id=1554546
      "virt-sysprep -a winxp-test-agent-1.qcow2 --operations machine-id",

      "sha256sum winxp-test-agent-1.qcow2 winxp-test-agent-2.qcow2 > SHA256SUMS",
    ]
  }
}

data "sshkey" "install" {}

source qemu "debian" {
  iso_url      = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  iso_checksum = "file:https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS"
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
  disk_size   = "16G"
  disk_additional_size = [ "32G" ]
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
