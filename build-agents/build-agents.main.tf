terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  alias = "vmhost01"
  # uri = "qemu+ssh://root@vmhost01.lan.solemnwarning.net/system?sshauth=privkey"
  uri = "qemu:///system"
}

provider "libvirt" {
  alias = "vmhost02"
  uri = "qemu+ssh://root@vmhost02.lan.solemnwarning.net/system?sshauth=privkey"
}

provider "libvirt" {
  alias = "vmhost03"
  uri = "qemu+ssh://root@vmhost03.lan.solemnwarning.net/system?sshauth=privkey"
}

provider "libvirt" {
  alias = "vmhost04"
  uri = "qemu+ssh://root@vmhost04.lan.solemnwarning.net/system?sshauth=privkey"
}

module "ipxwrapper_test_vmhost01" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu = 8
  spawn = 1
}

output "ipxwrapper_test_vmhost01_root_password" {
    value = "${module.ipxwrapper_test_vmhost01.root_password}"
    sensitive = true
}

module "ipxwrapper_test_vmhost02" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu = 8
  spawn = 1
}

output "ipxwrapper_test_vmhost02_root_password" {
    value = "${module.ipxwrapper_test_vmhost02.root_password}"
    sensitive = true
}

module "ipxwrapper_test_vmhost03" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 65536
  vcpu = 32
  spawn = 4
}

output "ipxwrapper_test_vmhost03_root_password" {
    value = "${module.ipxwrapper_test_vmhost03.root_password}"
    sensitive = true
}

module "ipxwrapper_test_vmhost04" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 65536
  vcpu = 28
  spawn = 4
}

output "ipxwrapper_test_vmhost04_root_password" {
    value = "${module.ipxwrapper_test_vmhost04.root_password}"
    sensitive = true
}

module "windows_build_vmhost01" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  memory = 16384
  vcpu   = 8
  spawn  = 1
}

module "windows_build_vmhost02" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  memory = 16384
  vcpu   = 8
  spawn  = 1
}

module "windows_build_vmhost03_a" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  hostname_suffix = "-a"
  domain = "build.solemnwarning.net"

  memory     = 49152
  vcpu       = 42
  spawn      = 1
  extra_tags = "big=true"
}

module "windows_build_vmhost03_b" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  hostname_suffix = "-b"
  domain = "build.solemnwarning.net"

  memory     = 49152
  vcpu       = 42
  spawn      = 1
  extra_tags = "big=true"
}

module "windows_build_vmhost04_a" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  hostname_suffix = "-a"
  domain = "build.solemnwarning.net"

  memory     = 49152
  vcpu       = 24
  spawn      = 1
  extra_tags = "big=true"
}

module "windows_build_vmhost04_b" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  hostname_suffix = "-b"
  domain = "build.solemnwarning.net"

  memory     = 49152
  vcpu       = 24
  spawn      = 1
  extra_tags = "big=true"
}

resource "tls_private_key" "buildkite_user_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output buildkite_user_public_ssh_key {
  value = tls_private_key.buildkite_user_ssh_key.public_key_openssh
}

module "debian_build_vmhost01" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 16384
  vcpu   = 8
}

output "debian_build_vmhost01_root_password" {
    value = "${module.debian_build_vmhost01.root_password}"
    sensitive = true
}

module "debian_build_vmhost02" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 16384
  vcpu   = 8
}

output "debian_build_vmhost02_root_password" {
    value = "${module.debian_build_vmhost02.root_password}"
    sensitive = true
}

module "debian_build_vmhost03_a" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  hostname_suffix = "-a"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 49152
  vcpu   = 42
}

output "debian_build_vmhost03_a_root_password" {
    value = "${module.debian_build_vmhost03_a.root_password}"
    sensitive = true
}

module "debian_build_vmhost03_b" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  hostname_suffix = "-b"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 49152
  vcpu   = 42
}

output "debian_build_vmhost03_b_root_password" {
    value = "${module.debian_build_vmhost03_b.root_password}"
    sensitive = true
}

module "debian_build_vmhost04_a" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  hostname_suffix = "-a"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 49152
  vcpu   = 24
}

output "debian_build_vmhost04_a_root_password" {
    value = "${module.debian_build_vmhost04_a.root_password}"
    sensitive = true
}

module "debian_build_vmhost04_b" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  hostname_suffix = "-b"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 49152
  vcpu   = 24
}

output "debian_build_vmhost04_b_root_password" {
    value = "${module.debian_build_vmhost04_b.root_password}"
    sensitive = true
}

module "freebsd_build_vmhost01" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  hostname_suffix = ""
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 8
}

output "freebsd_build_vmhost01_root_password" {
    value = "${module.freebsd_build_vmhost01.root_password}"
    sensitive = true
}

module "freebsd_build_vmhost02" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  hostname_suffix = ""
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 8
}

output "freebsd_build_vmhost02_root_password" {
    value = "${module.freebsd_build_vmhost02.root_password}"
    sensitive = true
}

module "freebsd_build_vmhost03" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  hostname_suffix = ""
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 49152
  vcpu   = 42
}

output "freebsd_build_vmhost03_root_password" {
    value = "${module.freebsd_build_vmhost03.root_password}"
    sensitive = true
}

module "freebsd_build_vmhost04" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  hostname_suffix = ""
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 49152
  vcpu   = 24
}

output "freebsd_build_vmhost04_root_password" {
    value = "${module.freebsd_build_vmhost04.root_password}"
    sensitive = true
}

module "copr_cli_vmhost01" {
  source    = "./copr-cli-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys
  copr_config = var.copr_config

  memory = 1024
  vcpu   = 2
}

output "copr_cli_vmhost01_root_password" {
    value = "${module.copr_cli_vmhost01.root_password}"
    sensitive = true
}

module "copr_cli_vmhost02" {
  source    = "./copr-cli-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys
  copr_config = var.copr_config

  memory = 1024
  vcpu   = 2
}

output "copr_cli_vmhost02_root_password" {
    value = "${module.copr_cli_vmhost02.root_password}"
    sensitive = true
}

module "winxp_test_vmhost01" {
  source    = "./winxp-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 8
  spawn = 4
}

output "winxp_test_vmhost01_root_password" {
    value = "${module.winxp_test_vmhost01.root_password}"
    sensitive = true
}

module "winxp_test_vmhost02" {
  source    = "./winxp-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 8
  spawn = 4
}

output "winxp_test_vmhost02_root_password" {
    value = "${module.winxp_test_vmhost02.root_password}"
    sensitive = true
}

module "winxp_test_vmhost03" {
  source    = "./winxp-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 24576
  vcpu = 24
  spawn = 10
}

output "winxp_test_vmhost03_root_password" {
    value = "${module.winxp_test_vmhost03.root_password}"
    sensitive = true
}

module "winxp_test_vmhost04" {
  source    = "./winxp-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 24576
  vcpu = 24
  spawn = 10
}

output "winxp_test_vmhost04_root_password" {
    value = "${module.winxp_test_vmhost04.root_password}"
    sensitive = true
}

module "macos1013_build_vmhost01" {
  source    = "./macos1013-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_username = var.macos_admin_username
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 4
}

module "macos1013_build_vmhost02" {
  source    = "./macos1013-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_username = var.macos_admin_username
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 4
}

module "macos14_build_vmhost01" {
  source    = "./macos14-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_username = var.macos_admin_username
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 4
}

module "macos14_build_vmhost02" {
  source    = "./macos14-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_username = var.macos_admin_username
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 4
}
