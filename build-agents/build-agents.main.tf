terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  alias = "vmhost01"
  uri = "qemu+ssh://root@vmhost01.lan.solemnwarning.net/system?sshauth=privkey"
}

provider "libvirt" {
  alias = "vmhost04"
  # uri = "qemu+ssh://root@vmhost04.lan.solemnwarning.net/system?sshauth=privkey"
  uri = "qemu:///system"
}

module "ipxwrapper_test_vmhost01" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
}

module "ipxwrapper_test_vmhost04" {
  source    = "./ipxwrapper-test-agent-deploy/"
  providers = {
    libvirt = libvirt.vmhost04
  }

  domain = "build.solemnwarning.net"

  buildkite_agent_token = var.buildkite_agent_token
  http_proxy_url = var.http_proxy_url
}

output "ipxwrapper_test_vmhost04_root_password" {
    value = "${module.ipxwrapper_test_vmhost04.root_password}"
    sensitive = true
}
