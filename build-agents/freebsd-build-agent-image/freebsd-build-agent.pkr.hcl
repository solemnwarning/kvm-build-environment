packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "output_dir" {
  type    = string
  default = "output"
}

build {
  sources = ["source.qemu.freebsd"]

  provisioner "shell" {
    inline = [
      "pkg install -y py311-cloud-init",
      "echo cloudinit_enable=YES >> /etc/rc.conf",
    ]
  }

  provisioner "file" {
    source      = "xvfb-run"
    destination = "/usr/local/bin/xvfb-run"
  }

  provisioner "shell" {
    inline = [
      "ASSUME_ALWAYS_YES=yes pkg install \\",
      "  bash           \\",
      "  botan2         \\",
      "  capstone4      \\",
      "  git            \\",
      "  gmake          \\",
      "  jansson        \\",
      "  jq             \\",
      "  lua53          \\",
      "  lua53-luarocks \\",
      "  pidof          \\",
      "  pkgconf        \\",
      "  wget           \\",
      "  wx30-gtk3      \\",
      "  xauth          \\",
      "  xorg-fonts     \\",
      "  xorg-vfbserver",

      "luarocks53 install busted",

      "chmod 0755 /usr/local/bin/xvfb-run",
    ]

    timeout = "1h"
  }

  provisioner "shell" {
    script = "install-buildkite.sh"
    timeout = "10m"
  }

  provisioner "file" {
    source      = "buildkite-agent.cfg"
    destination = "/usr/local/etc/buildkite-agent/buildkite-agent.cfg"
  }

  provisioner "file" {
    source      = "buildkite-environment-hook"
    destination = "/usr/local/etc/buildkite-agent/hooks/environment"
  }

  provisioner "shell" {
    inline = [
      "chown root:buildkite-agent /usr/local/etc/buildkite-agent/buildkite-agent.cfg",
      "chmod 0640 /usr/local/etc/buildkite-agent/buildkite-agent.cfg",

      "chmod 0755 /usr/local/etc/buildkite-agent/hooks/environment",
    ]
  }

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cd ${var.output_dir}/",
      "sha256sum freebsd-build-agent.qcow2 > SHA256SUMS",
    ]
  }
}

source qemu "freebsd" {
  iso_url      = "https://download.freebsd.org/ftp/releases/VM-IMAGES/14.2-RELEASE/amd64/Latest/FreeBSD-14.2-RELEASE-amd64-BASIC-CLOUDINIT.ufs.qcow2.xz"
  iso_checksum = "none"
  # iso_checksum = "file:https://download.freebsd.org/ftp/snapshots/VM-IMAGES/14.0-STABLE/amd64/Latest/CHECKSUM.SHA256"
  disk_image   = true

  boot_wait = "5m"
  boot_key_interval = "50ms"
  boot_command = [
    # Login as root (blank password by default)
    "root<enter>",
    "<wait>",

    # Set password to "packer"
    "passwd root<enter>",
    "packer<enter>",
    "packer<enter>",

    # Allow logging in over SSH using root password
    "echo PermitRootLogin yes >> /etc/ssh/sshd_config<enter>",
    "/etc/rc.d/sshd restart<enter>",
  ]

  # Create a full copy of the base image
  use_backing_file = false

  cpus        = 4
  memory      = 4096
  disk_size   = 24000
  accelerator = "kvm"

  headless = true
  vnc_bind_address = "0.0.0.0"

  # SSH ports to redirect to the VM being built
  host_port_min = 2222
  host_port_max = 2229

  ssh_username     = "root"
  ssh_password     = "packer"
  ssh_wait_timeout = "1000s"

  # Disable root password when we are done
  shutdown_command = "pw usermod root -w no && /sbin/shutdown -p now"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "freebsd-build-agent.qcow2"
}
