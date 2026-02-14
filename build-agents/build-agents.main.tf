terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
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

  template_dir = "${path.root}/output/vmhost01/ipxwrapper-test-agent"

  hostname_suffix = "-vm01"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu = 8
  spawn = 1
}

module "ipxwrapper_test_vmhost02" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  template_dir = "${path.root}/output/vmhost02/ipxwrapper-test-agent"

  hostname_suffix = "-vm02"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu = 8
  spawn = 1
}

module "ipxwrapper_test_vmhost03" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  template_dir = "${path.root}/output/vmhost03/ipxwrapper-test-agent"

  hostname_suffix = "-vm03"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 65536
  vcpu = 32
  spawn = 4
}

module "ipxwrapper_test_vmhost04" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  template_dir = "${path.root}/output/vmhost04/ipxwrapper-test-agent"

  hostname_suffix = "-vm04"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 65536
  vcpu = 28
  spawn = 4
}

module "windows_build_vmhost01" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  template_dir = "${path.root}/output/vmhost01/windows-build-agent"

  hostname_suffix = "-vm01"
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

  template_dir = "${path.root}/output/vmhost02/windows-build-agent"

  hostname_suffix = "-vm02"
  domain = "build.solemnwarning.net"

  memory = 16384
  vcpu   = 8
  spawn  = 1
}

module "windows_build_vmhost03" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  template_dir = "${path.root}/output/vmhost03/windows-build-agent"

  hostname_suffix = "-vm03"
  domain = "build.solemnwarning.net"

  memory     = 32768
  vcpu       = 28
  spawn      = 1
  extra_tags = "big=true"
}

module "windows_build_vmhost04" {
  source    = "./windows-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  template_dir = "${path.root}/output/vmhost04/windows-build-agent"

  hostname_suffix = "-vm04"
  domain = "build.solemnwarning.net"

  memory     = 32768
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

  template_dir = "${path.root}/output/vmhost01/debian-build-agent"

  hostname_suffix = "-vm01"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 16384
  vcpu   = 8
}

module "debian_build_vmhost02" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  template_dir = "${path.root}/output/vmhost02/debian-build-agent"

  hostname_suffix = "-vm02"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 16384
  vcpu   = 8
}

module "debian_build_vmhost03" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  template_dir = "${path.root}/output/vmhost03/debian-build-agent"

  hostname_suffix = "-vm03"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 32768
  vcpu   = 28
}

module "debian_build_vmhost04" {
  source    = "./debian-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  template_dir = "${path.root}/output/vmhost04/debian-build-agent"

  hostname_suffix = "-vm04"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  buildkite_user_ssh_key = tls_private_key.buildkite_user_ssh_key

  memory = 32768
  vcpu   = 24
}

module "freebsd_build_vmhost01" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  template_dir = "${path.root}/output/vmhost01/freebsd-build-agent"

  hostname_suffix = "-vm01"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 8
}

module "freebsd_build_vmhost02" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost02
  }

  template_dir = "${path.root}/output/vmhost02/freebsd-build-agent"

  hostname_suffix = "-vm02"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 8
}

module "freebsd_build_vmhost03" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost03
  }

  template_dir = "${path.root}/output/vmhost03/freebsd-build-agent"

  hostname_suffix = "-vm03"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 12
}

module "freebsd_build_vmhost04" {
  source    = "./freebsd-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  template_dir = "${path.root}/output/vmhost04/freebsd-build-agent"

  hostname_suffix = "-vm04"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 16384
  vcpu   = 12
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

module "winxp_test_vmhost01" {
  source    = "./winxp-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  ip_and_prefix = "172.24.136.2/27"
  gateway = "172.24.136.1"
  dns_server = "172.24.128.1"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys

  memory = 1024
  vcpu = 2
}

module "macos1013_build_vmhost01" {
  source    = "./macos1013-build-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  template_dir = "${path.root}/output/vmhost01/macos1013-build-agent"

  hostname_suffix = "-vm01"
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

  template_dir = "${path.root}/output/vmhost02/macos1013-build-agent"

  hostname_suffix = "-vm02"
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

  template_dir = "${path.root}/output/vmhost01/macos14-build-agent"

  hostname_suffix = "-vm01"
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

  template_dir = "${path.root}/output/vmhost02/macos14-build-agent"

  hostname_suffix = "-vm02"
  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
  admin_username = var.macos_admin_username
  admin_ssh_keys = var.admin_ssh_keys

  memory = 8192
  vcpu = 4
}
