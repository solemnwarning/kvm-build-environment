terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

data "local_file" "image_version" {
  filename = "${ path.root }/macos14-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/macos.qcow2"
  opencore_path = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/OpenCore.qcow2"
  ovmf_path     = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/OVMF_CODE.fd"
  vars_path     = "${ path.root }/macos14-build-agent-image/builds/${ local.image_version }/OVMF_VARS.fd"

  output_image_name = "macos14-build-agent-${ local.image_version }.qcow2"
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

resource "local_file" "opencore" {
  source = local.opencore_path
  filename = "${ var.template_dir }/OpenCore.qcow2"
}

resource "local_file" "ovmf_code" {
  source = local.ovmf_path
  filename = "${ var.template_dir }/OVMF_CODE.fd"
}

resource "local_file" "ovmf_vars" {
  source = local.vars_path
  filename = "${ var.template_dir }/OVMF_VARS.fd"
}

resource "local_file" "domain-xml" {
  content  = templatefile("${ path.module }/macos14-build-agent.xml.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain          = var.domain

    memory = var.memory
    vcpu   = var.vcpu

    image_name = local.output_image_name
  })

  filename = "${ var.template_dir }/macos14-build-agent.xml"
}

resource "local_file" "meta-data" {
  content = ""
  filename = "${ var.template_dir }/cloud-init/meta-data"
}

resource "local_file" "user-data" {
  content  = templatefile("${ path.module }/macos14-build-agent.user-data.tftpl", {
    domain = "${ var.domain }"

    http_proxy_url        = "${ var.http_proxy_url }"
    admin_username        = "${ var.admin_username }"
    admin_ssh_keys        = "${ var.admin_ssh_keys }"
    buildkite_agent_token = "${ var.buildkite_agent_token }"
  })

  filename = "${ var.template_dir }/cloud-init/user-data.TT"
}
