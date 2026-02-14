terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

data "local_file" "disk1_image_version" {
  filename = "${ path.root }/ipxwrapper-test-agent-image/builds/ipxwrapper-test-agent/latest-version"
}

data "local_file" "disk2_image_name" {
  filename = "${ path.root }/ipxwrapper-test-agent-image/builds/ipxwrapper-test-images/latest-version"
}

locals {
  disk1_image_version = chomp(data.local_file.disk1_image_version.content)
  disk1_image_name    = "ipxwrapper-test-agent-${ local.disk1_image_version }.qcow2"
  disk1_image_path    = "${ path.root }/ipxwrapper-test-agent-image/builds/ipxwrapper-test-agent/${ local.disk1_image_version }/ipxwrapper-test-agent.qcow2"

  disk2_image_name = chomp(data.local_file.disk2_image_name.content)
  disk2_image_path = "${ path.root }/ipxwrapper-test-agent-image/builds/ipxwrapper-test-images/${ local.disk2_image_name }"
}

# Create a symlink to the disk image in the template output directory.
# This would be simpler as a local_file, but then we would have to have
# multiple copies of the image floating around.

resource "terraform_data" "disk1_symlink" {
  triggers_replace = [
    abspath(local.disk1_image_path),
    "${ var.template_dir }/${ local.disk1_image_name }",
  ]

  input = [
    abspath(local.disk1_image_path),
    "${ var.template_dir }/${ local.disk1_image_name }",
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

resource "terraform_data" "disk2_symlink" {
  triggers_replace = [
    abspath(local.disk2_image_path),
    "${ var.template_dir }/${ local.disk2_image_name }",
  ]

  input = [
    abspath(local.disk2_image_path),
    "${ var.template_dir }/${ local.disk2_image_name }",
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
  content  = templatefile("${ path.module }/ipxwrapper-test-agent.xml.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain          = var.domain

    memory = var.memory
    vcpu   = var.vcpu

    disk1_name = local.disk1_image_name
    disk2_name = local.disk2_image_name
  })

  filename = "${ var.template_dir }/ipxwrapper-test-agent.xml"
}

resource "local_file" "meta-data" {
  content = ""
  filename = "${ var.template_dir }/cloud-init/meta-data"
}

resource "local_file" "network-config" {
  content = templatefile("${ path.module }/ipxwrapper-test-agent.network-config.tftpl", {})
  filename = "${ var.template_dir }/cloud-init/network-config"
}

resource "local_file" "user-data" {
  content = templatefile("${ path.module }/ipxwrapper-test-agent.user-data.tftpl", {
    hostname_suffix = var.hostname_suffix
    domain   = var.domain

    buildkite_agent_token = var.buildkite_agent_token
    buildkite_agent_spawn = var.spawn
    http_proxy_url        = var.http_proxy_url
    admin_ssh_keys        = var.admin_ssh_keys
  })

  filename = "${ var.template_dir }/cloud-init/user-data.TT"
}
