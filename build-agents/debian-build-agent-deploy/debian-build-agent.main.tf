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

resource "tls_private_key" "https_key" {
  algorithm = "RSA"
  rsa_bits = 3072
}

data "local_file" "image_version" {
  filename = "${ path.root }/debian-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/debian-build-agent-image/builds/${ local.image_version }/debian-build-agent.qcow2"

  output_image_name = "debian-build-agent-${ local.image_version }.qcow2"
}

resource "tls_private_key" "ccache_client_key" {
  algorithm = "RSA"
  rsa_bits = 3072
}

resource "tls_cert_request" "ccache_client_csr" {
  private_key_pem = tls_private_key.ccache_client_key.private_key_pem

  subject {
    common_name = "debian-build-agent"
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
  content  = templatefile("${ path.module }/debian-build-agent.xml.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain          = var.domain

    memory = var.memory
    vcpu   = var.vcpu

    image_name = local.output_image_name
  })

  filename = "${ var.template_dir }/debian-build-agent.xml"
}

resource "local_file" "meta-data" {
  content = ""
  filename = "${ var.template_dir }/cloud-init/meta-data"
}

resource "local_file" "network-config" {
  content = templatefile("${ path.module }/debian-build-agent.network-config.tftpl", {})
  filename = "${ var.template_dir }/cloud-init/network-config"
}

resource "local_file" "user-data" {
  content  = templatefile("${ path.module }/debian-build-agent.user-data.tftpl", {
    domain = var.domain

    buildkite_agent_token  = var.buildkite_agent_token
    http_proxy_url         = var.http_proxy_url
    admin_ssh_keys         = var.admin_ssh_keys
    buildkite_user_ssh_key = var.buildkite_user_ssh_key

    ccache_cache_https_cert  = data.terraform_remote_state.build_infrastructure.outputs.ccache_cache_https_cert
    ccache_cache_client_cert = tls_locally_signed_cert.ccache_client_cert.cert_pem
    ccache_cache_client_key  = tls_private_key.ccache_client_key.private_key_pem
  })

  filename = "${ var.template_dir }/cloud-init/user-data.TT"
}
