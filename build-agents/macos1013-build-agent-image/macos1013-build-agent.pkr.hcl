packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "base_dir" {
  type    = string
  default = "../macos-10.13-qemu-packer/base/"
}

variable "output_dir" {
  type    = string
  default = "output/"
}

variable "uefi_firmware" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
}

locals {
  buildkite_url = "https://github.com/buildkite/agent/releases/download/v3.35.2/buildkite-agent-darwin-amd64-3.35.2.tar.gz"
  buildkite_tar = basename(local.buildkite_url)

  xcode_tools_url = "https://archive.org/download/command-line-tools-for-xcode-9.4.1/Command%20Line%20Tools%20%28macOS%20High%20Sierra%20version%2010.13%29.pkg"
  xcode_tools_pkg = "xcode-command-line-tools-9.4.1.pkg"

  yq_url = "https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_darwin_amd64"
  yq_bin = "yq_darwin_amd64-4.45.1"
}

build {
  sources = ["source.qemu.macos"]

  # We need to explicitly enable TRIM support since we aren't using official Apple-approved disks.

  provisioner "shell" {
    inline = [
      "yes | sudo trimforce enable",
    ]

    expect_disconnect = true
    pause_after = "2m"
  }

  # Download and install pre-compiled yq executable.

  provisioner "shell-local" {
    inline = [
      "test -e .cache/${ local.yq_bin } || wget -O .cache/${ local.yq_bin } ${ local.yq_url }",
    ]
  }

  provisioner "file" {
    source = ".cache/${ local.yq_bin }"
    destination = "/tmp/"
    generated = true
  }

  provisioner "shell" {
    inline = [
      "sudo install -d /usr/local/bin/",
      "sudo install -m 0755 /tmp/${ local.yq_bin } /usr/local/bin/yq",

      "rm -f /tmp/${ local.yq_bin }",
    ]
  }

  # Install macos-init.

  provisioner "file" {
    sources = [
      "../macos-init",
      "macos-init.conf",
    ]

    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "cd /tmp/macos-init/",
      "sudo ./install.sh",

      "sudo install -m 0644 /tmp/macos-init.conf /usr/local/etc/macos-init.conf",

      "rm -rf /tmp/macos-init/",
      "rm -f /tmp/macos-init.conf",
    ]
  }

  # Download and install Xcode command line tools (for git)

  provisioner "shell-local" {
    inline = [
      "test -e .cache/${ local.xcode_tools_pkg } || wget -O .cache/${ local.xcode_tools_pkg } ${ local.xcode_tools_url }",
    ]
  }

  provisioner "file" {
    source = ".cache/${ local.xcode_tools_pkg }"
    destination = "/tmp/"
    generated = true
  }

  provisioner "shell" {
    inline = [
      "sudo installer -pkg /tmp/${ local.xcode_tools_pkg } -target /",
      "rm -f /tmp/${ local.xcode_tools_pkg }",
    ]
  }

  # Download and install the Buildkite agent

  provisioner "shell-local" {
    inline = [
      "test -e .cache/${ local.buildkite_tar } || wget -O .cache/${ local.buildkite_tar} ${ local.buildkite_url }",
    ]
  }

  provisioner "file" {
    sources = [
      "99-buildkite-configure",
      "buildkite-agent.cfg.in",
      "buildkite-agent.sudoers",
      "buildkite-agent-wrapper",
      "com.apple.SetupAssistant.plist",
      "com.buildkite.buildkite-agent.LaunchAgent.plist",
      "kcpassword",
    ]

    destination = "/tmp/"
  }

  provisioner "file" {
    source = ".cache/${ local.buildkite_tar }"
    destination = "/tmp/"
    generated = true
  }

  provisioner "shell" {
    inline = [
      "mkdir /tmp/buildkite/",
      "tar -C /tmp/buildkite/ -xvf /tmp/${ local.buildkite_tar }",
      "sudo install -m 0755 /tmp/buildkite/buildkite-agent /usr/local/bin/",

      "sudo mkdir -p /etc/buildkite-agent/hooks/",
      "sudo install -m 0644 /tmp/buildkite-agent.cfg.in /etc/buildkite-agent/",

      "sudo install -m 0755 /tmp/buildkite-agent-wrapper /usr/local/bin/",

      "sudo install -m 0755 /tmp/99-buildkite-configure /usr/local/share/macos-init/scripts/",
      "sudo install -m 0600 /tmp/buildkite-agent.sudoers /etc/sudoers.d/buildkite-agent",

      # Create an unprivileged account for running the buildkite agent.
      "sudo sysadminctl -adminUser packer -adminPassword packer -addUser buildkite-agent -home /var/lib/buildkite-agent/",
      "sudo mkdir -p ~buildkite-agent/builds/",

      # Skip the first-time setup wizard for the buildkite user.
      "sudo mkdir -p ~buildkite-agent/Library/Preferences/",
      "sudo cp /tmp/com.apple.SetupAssistant.plist ~buildkite-agent/Library/Preferences/",

      # Install LaunchAgent for running buildkite-agent with GUI console access.
      "sudo mkdir -p ~buildkite-agent/Library/LaunchAgents/",
      "sudo install -m 0755 /tmp/com.buildkite.buildkite-agent.LaunchAgent.plist ~buildkite-agent/Library/LaunchAgents/",

      "sudo chown -R buildkite-agent ~buildkite-agent/",

      # Update the autologin username/password to the buildkite user.
      "sudo defaults write /Library/Preferences/com.apple.loginwindow 'autoLoginUser' 'buildkite-agent'",
      "sudo install -m 0600 /tmp/kcpassword /private/etc/kcpassword",

      "rm -f /tmp/99-buildkite-configure",
      "rm -f /tmp/buildkite-agent.cfg.in",
      "rm -f /tmp/buildkite-agent.sudoers",
      "rm -f /tmp/buildkite-agent-wrapper",
      "rm -f /tmp/com.apple.SetupAssistant.plist",
      "rm -f /tmp/com.buildkite.buildkite-agent.LaunchAgent.plist",
      "rm -f /tmp/kcpassword",
      "rm -f /tmp/${ local.buildkite_tar }",
    ]
  }

  # Copy other files from base directory to output and generate checksums.

  post-processor "shell-local" {
    keep_input_artifact = true
    inline = [
      "cp ${var.base_dir}/OpenCore.qcow2 ${var.output_dir}/",
      "cp ${var.base_dir}/OVMF_VARS.fd ${var.output_dir}/",

      "cd ${var.output_dir}/",
      "sha256sum macos.qcow2 OpenCore.qcow2 OVMF_VARS.fd > SHA256SUMS",
    ]
  }
}

source qemu "macos" {
  iso_url          = "${var.base_dir}/macos.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  skip_resize_disk = true

  # Create a full copy of the base image
  use_backing_file = false

  machine_type = "q35"
  net_device   = "vmxnet3"

  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  efi_boot         = true
  efi_drop_efivars = false

  qemuargs = [
    [ "-device", "isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" ],
    [ "-smbios", "type=2" ],

    [ "-cpu", "Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check" ],

    [ "-usb" ],
    [ "-device", "usb-kbd" ],
    [ "-device", "usb-tablet" ],

    [ "-device", "ahci,id=ahci" ],

    [ "-drive", "if=none,id=disk0,format=qcow2,file=${var.base_dir}/OpenCore.qcow2" ],
    [ "-device", "ide-hd,drive=disk0,bus=ahci.0,rotation_rate=1" ],

    [ "-drive", "if=none,id=disk1,format=qcow2,file=${var.output_dir}/macos.qcow2,cache=unsafe,discard=unmap,detect-zeroes=unmap" ],
    [ "-device", "ide-hd,drive=disk1,bus=ahci.1,rotation_rate=1" ],

    [ "-drive", "if=pflash,format=raw,readonly=true,file=${var.uefi_firmware}" ],
    [ "-drive", "if=pflash,format=raw,readonly=true,file=${var.base_dir}/OVMF_VARS.fd" ],
  ]

  # Comment this line to enable the local QEMU display.
  headless = true

  # Uncomment this line to enable remove VNC access to the display.
  # vnc_bind_address = "0.0.0.0"

  communicator = "ssh"
  ssh_username = "packer"
  ssh_password = "packer"

  shutdown_command = "sudo shutdown -h now"
  shutdown_timeout = "30m"

  # Builds a compact image
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_cache         = "unsafe"

  format           = "qcow2"
  output_directory = "${var.output_dir}"
  vm_name          = "macos.qcow2"
}
