terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  hostname = "freebsd-build${ var.hostname_suffix }-${ random_id.suffix.hex }"
}

data "local_file" "image_version" {
  filename = "${ path.root }/freebsd-build-agent-image/builds/latest-version"
}

locals {
  image_version = chomp(data.local_file.image_version.content)
  image_path    = "${ path.root }/freebsd-build-agent-image/builds/${ local.image_version }/freebsd-build-agent.qcow2"

  output_image_name = "freebsd-build-agent-${ local.image_version }.qcow2"
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
  content  = templatefile("${ path.module }/freebsd-build-agent.xml.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain          = var.domain

    memory = var.memory
    vcpu   = var.vcpu

    image_name = local.output_image_name
  })

  filename = "${ var.template_dir }/freebsd-build-agent.xml"
}

resource "local_file" "meta-data" {
  content = ""
  filename = "${ var.template_dir }/cloud-init/meta-data"
}

resource "local_file" "network-config" {
  content = ""
  filename = "${ var.template_dir }/cloud-init/network-config"
}

resource "local_file" "user-data" {
  content = templatefile("${ path.module }/freebsd-build-agent.user-data.tftpl", {
    hostname = local.hostname
    domain   = var.domain

    buildkite_agent_token  = var.buildkite_agent_token
    http_proxy_url         = var.http_proxy_url
    admin_ssh_keys         = var.admin_ssh_keys
  })

  filename = "${ var.template_dir }/cloud-init/user-data.TT"
}
