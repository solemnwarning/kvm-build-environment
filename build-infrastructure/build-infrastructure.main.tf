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

# module "snappass" {
#   source    = "./snappass-server-deploy/"
#   providers = {
#     libvirt = libvirt.vmhost01
#   }
#
#   hostname = "snappass"
#   domain = "build.solemnwarning.net"
#
#   ip_and_prefix = "172.24.134.8/26"
#   gateway = "172.24.134.1"
#   dns_server = "172.24.128.1"
# }

# output "snappass_root_password" {
#     value = "${module.snappass.root_password}"
#     sensitive = true
# }

# output "snappass_https_cert" {
#     value = "${module.snappass.https_cert}"
# }

# resource "local_file" "snappass_https_cert" {
#     filename = "${ path.root }/snappass.build.solemnwarning.net.crt"
#     file_permission = "0644"
#
#     content = "${module.snappass.https_cert}"
# }

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

  admin_ssh_keys = var.admin_ssh_keys
}

output "vcpkg_cache_https_cert" {
    value = "${module.vcpkg_cache.https_cert}"
}

resource "local_file" "vcpkg_cache_https_cert" {
    filename = "${ path.root }/vcpkg-cache.build.solemnwarning.net.crt"
    file_permission = "0644"

    content = "${module.vcpkg_cache.https_cert}"
}

module "git_cache" {
  source    = "./git-cache-server-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  hostname = "git-cache"
  domain = "build.solemnwarning.net"

  ip_and_prefix = "172.24.134.6/26"
  gateway = "172.24.134.1"
  dns_server = "172.24.128.1"

  http_proxy_url = var.http_proxy_url
  admin_ssh_keys = var.admin_ssh_keys
}

output "git_cache_https_cert" {
    value = "${module.git_cache.https_cert}"
}

resource "local_file" "git_cache_https_cert" {
    filename = "${ path.root }/git-cache.build.solemnwarning.net.crt"
    file_permission = "0644"

    content = "${module.git_cache.https_cert}"
}

module "ccache_cache" {
  source    = "./ccache-cache-server-deploy/"
  providers = {
    libvirt = libvirt.vmhost01
  }

  hostname = "ccache-cache"
  domain = "build.solemnwarning.net"

  ip_and_prefix = "172.24.134.8/26"
  gateway = "172.24.134.1"
  dns_server = "172.24.128.1"

  admin_ssh_keys = var.admin_ssh_keys
}

output "ccache_cache_https_cert" {
    value = "${module.ccache_cache.https_server_cert}"
}

output "ccache_cache_https_auth_ca_cert" {
    value = "${module.ccache_cache.https_auth_ca_cert}"
}

output "ccache_cache_https_auth_ca_key" {
    value = "${module.ccache_cache.https_auth_ca_key}"
    sensitive = true
}
