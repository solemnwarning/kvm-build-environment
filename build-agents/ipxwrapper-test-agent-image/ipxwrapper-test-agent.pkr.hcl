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
      "buildkite-checkout-hook",
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
      # Disable use of systemd-resolved so that resolution of .local names from
      # my LAN DNS server works.
      "echo 'hosts: files myhostname dns' >> /etc/nsswitch.conf",

      # Partition disk and create btrfs filesystem for storing ipxtester images
      "apt-get -y update",
      "apt-get -y install parted btrfs-progs",

      "echo Partitioning disk...",
      "lsblk",
      "blkid",

      "parted -s -a optimal /dev/vdb mklabel gpt",
      # "parted -s -a optimal /dev/vdb mklabel msdos",
      "parted -s -a optimal /dev/vdb mkpart primary btrfs 0% 100%",
      "partprobe /dev/vdb",
      "mkfs.btrfs -f -L ipxtester-data /dev/vdb1",

      "mkdir /mnt/ipxtester-data/",
      "echo LABEL=ipxtester-data  /mnt/ipxtester-data/  auto  defaults  0  0 >> /etc/fstab",

      "mount /mnt/ipxtester-data/",
      "mkdir /mnt/ipxtester-data/images/",
      "mkdir /mnt/ipxtester-data/tmp/",

      # Install Buildkite agent

      "apt-get -y update",
      "apt-get -y install apt-transport-https dirmngr wget gpg gpg-agent",
      "wget -O - https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | gpg --dearmor -o /etc/apt/trusted.gpg.d/buildkite-agent-keyring.gpg",
      "echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list",

      "apt-get -y update",
      "apt-get -y install buildkite-agent",

      "install -m 0755 -o root -g root /tmp/buildkite-checkout-hook    /etc/buildkite-agent/hooks/checkout",
      "install -m 0755 -o root -g root /tmp/buildkite-environment-hook /etc/buildkite-agent/hooks/environment",
      "install -m 0644 -o root -g root /tmp/buildkite-agent.cfg        /etc/buildkite-agent/buildkite-agent.cfg",

      "systemctl enable buildkite-agent.service",

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
    ]
  }

  # Install ipxtester and depedencies

  provisioner "file" {
    sources = [
      "buildkite-agent.sshconfig",
      "ipxtester.ini",
      "ipxtester-init.service",
      "ipxwrapper-ci/ipxtester",
      "ipxwrapper-ci/ssh-keys/ipxtest-insecure.rsa",
    ]

    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "apt-get install -y libconfig-ini-perl libipc-run-perl libnetaddr-ip-perl libio-fdpass-perl mtools",
      "install -D -m 0755 -o root -g root /tmp/ipxtester     /opt/ipxtester/ipxtester",
      "install -D -m 0755 -o root -g root /tmp/ipxtester.ini /opt/ipxtester/ipxtester.ini",

      "install -d -m 0755 -o buildkite-agent -g buildkite-agent                                /var/lib/buildkite-agent/.ssh/",
      "install -D -m 0644 -o buildkite-agent -g buildkite-agent /tmp/buildkite-agent.sshconfig /var/lib/buildkite-agent/.ssh/config",
      "install -D -m 0600 -o buildkite-agent -g buildkite-agent /tmp/ipxtest-insecure.rsa      /var/lib/buildkite-agent/.ssh/ipxtest-insecure.rsa",

      "cat > /usr/local/bin/ipxtester <<EOF",
      "#!/bin/sh",
      "exec /opt/ipxtester/ipxtester \"\\$@\"",
      "EOF",

      "chmod 0755 /usr/local/bin/ipxtester",

      "chown buildkite-agent /mnt/ipxtester-data/tmp/",

      "perl -c /opt/ipxtester/ipxtester",

      "install -m 0644 /tmp/ipxtester-init.service /etc/systemd/system/",
      "systemctl daemon-reload",
      "systemctl enable ipxtester-init.service",
    ]
  }

  # Upload VM disk images

  provisioner "file" {
    source = "ipxtester-images/ipxtest-director-2024-07-03"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-winXPx86-2023-09-11"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-win7x64-2023-09-12"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-win81x86-2023-09-11"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-win10x64-2025-07-27"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-win11x64-2025-07-31"
    destination = "/mnt/ipxtester-data/images/"
  }

  provisioner "file" {
    source = "ipxtester-images/ipxtest-win98-2024-11-03"
    destination = "/mnt/ipxtester-data/images/"
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

      "mv ipxwrapper-test-agent.qcow2 ipxwrapper-test-agent-1.qcow2",
      "mv ipxwrapper-test-agent.qcow2-1 ipxwrapper-test-agent-2.qcow2",

      # Clear any state from the machine image (logs, caches, keys, etc).
      "virt-sysprep -a ipxwrapper-test-agent-1.qcow2 -v --run-command 'fstrim --all --verbose'",

      # Work around https://bugzilla.redhat.com/show_bug.cgi?id=1554546
      "virt-sysprep -a ipxwrapper-test-agent-1.qcow2 -v --operations machine-id",

      "sha256sum ipxwrapper-test-agent-1.qcow2 ipxwrapper-test-agent-2.qcow2 > SHA256SUMS",
    ]
  }
}

data "sshkey" "install" {}

source qemu "debian" {
  iso_url      = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  iso_checksum = "file:https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS"
  # iso_url      = "https://cloud.debian.org/images/cloud/bookworm/20241004-1890/debian-12-genericcloud-amd64-20241004-1890.qcow2"
  # iso_checksum = "file:https://cloud.debian.org/images/cloud/bookworm/20241004-1890/SHA512SUMS"
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
  disk_additional_size = [ "120G" ]
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
  vm_name          = "ipxwrapper-test-agent.qcow2"
}
