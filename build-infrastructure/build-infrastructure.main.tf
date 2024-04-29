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

module "snappass" {
  source    = "./snappass-server-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  hostname = "snappass"
  domain = "build.solemnwarning.net"

  ip_and_prefix = "172.24.134.8/26"
  gateway = "172.24.134.1"
  dns_server = "172.24.128.1"
}

output "snappass_root_password" {
    value = "${module.snappass.root_password}"
    sensitive = true
}

output "snappass_https_cert" {
    value = "${module.snappass.https_cert}"
}

resource "local_file" "snappass_https_cert" {
    filename = "${ path.root }/snappass.build.solemnwarning.net.crt"
    file_permission = "0644"

    content = "${module.snappass.https_cert}"
}

module "vcpkg_cache" {
  source    = "./vcpkg-cache-server-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  hostname = "vcpkg-cache"
  domain = "build.solemnwarning.net"

  ip_and_prefix = "172.24.134.7/26"
  gateway = "172.24.134.1"
  dns_server = "172.24.128.1"
}

output "vcpkg_cache_root_password" {
    value = "${module.vcpkg_cache.root_password}"
    sensitive = true
}

output "vcpkg_cache_https_cert" {
    value = "${module.vcpkg_cache.https_cert}"
}

resource "local_file" "vcpkg_cache_https_cert" {
    filename = "${ path.root }/vcpkg-cache.build.solemnwarning.net.crt"
    file_permission = "0644"

    content = "${module.vcpkg_cache.https_cert}"
}
