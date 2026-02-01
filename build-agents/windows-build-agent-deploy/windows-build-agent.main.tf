terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

data "terraform_remote_state" "build_infrastructure" {
  backend = "local"

  config = {
    path = "${abspath(path.root)}/../build-infrastructure/terraform.tfstate"
  }
}

data "local_file" "image_version" {
  filename = "${ path.root }/windows-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/windows-build-agent-image/builds/${ local.image_version }/windows-build-agent.qcow2"

  output_image_name = "windows-build-agent-${ local.image_version }.qcow2"
}

resource "tls_private_key" "ccache_client_key" {
  algorithm = "RSA"
  rsa_bits = 3072
}

resource "tls_cert_request" "ccache_client_csr" {
  private_key_pem = tls_private_key.ccache_client_key.private_key_pem

  subject {
    common_name = "windows-build-agent"
  }
}

resource "tls_locally_signed_cert" "ccache_client_cert" {
  cert_request_pem   = tls_cert_request.ccache_client_csr.cert_request_pem
  ca_cert_pem        = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_auth_ca_cert
  ca_private_key_pem = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_auth_ca_key

  validity_period_hours = 17520  # 2 years
  early_renewal_hours   = 4380   # 6 months

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# Create a symlink to the disk image in the template output directory.
# This would be simpler as a local_file, but then we would have to have
# multiple copies of the image floating around.

resource "terraform_data" "disk_symlink" {
  triggers_replace = [
    abspath(local.image_path),
    "${ var.template_dir }/${ local.output_image_name }",
  ]

  input = [
    abspath(local.image_path),
    "${ var.template_dir }/${ local.output_image_name }",
  ]

  provisioner "local-exec" {
    environment = {
      SOURCE = self.output[0]
      DEST = self.output[1]
    }

    command = "mkdir -p \"$(dirname \"$DEST\")\" && ln -s \"$SOURCE\" \"$DEST\""
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue

    environment = {
      DEST = self.output[1]
    }

    command = "rm -f \"$DEST\""
  }
}

resource "local_file" "domain-xml" {
  content  = templatefile("${ path.module }/windows-build-agent.xml.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain          = var.domain

    memory = var.memory
    vcpu   = var.vcpu

    image_name = local.output_image_name
  })

  filename = "${ var.template_dir }/windows-build-agent.xml"
}

resource "local_file" "user-data" {
  # Ensure user_data has DOS line endings for our horrible batch script to be
  # able to parse it correctly.
  content = replace(replace(
    templatefile("${ path.module }/windows-build-agent.user-data.tftpl", {
      spawn = var.spawn
      extra_tags = var.extra_tags
      git_cache_https_cert = data.terraform_remote_state.build_infrastructure.outputs.git_cache_https_cert
      vcpkg_cache_https_cert = data.terraform_remote_state.build_infrastructure.outputs.vcpkg_cache_https_cert
      ccache_cache_https_cert = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_cert
      ccache_cache_client_cert = tls_locally_signed_cert.ccache_client_cert.cert_pem
      ccache_cache_client_key = tls_private_key.ccache_client_key.private_key_pem
  }), "\r", ""), "\n", "\r\n")

  filename = "${ var.template_dir }/cloud-init/user-data.TT"
}
