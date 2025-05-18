# kvm-build-environment

## What is this?

This is a collection of scripts and Packer/Terraform definitions that build and deploy my various Buildkite CI build agents on a self-hosted KVM cluster.

This is an evolution of my earlier [build-server-deployment](https://github.com/solemnwarning/build-server-deployment) project which deployed to AWS EC2, I chose to rework it as a self-hosted KVM cluster for both (long term) cost savings and fun.

This repository isn't a simple unpack-and-run affair - at the very least the Terraform modules will need updating to suit your VM host(s) and configuration such as IP addresses and hostnames will need altering, please feel free to open an issue if you have any questions about how it holds together that aren't answered in this README.

## Repository structure

The repository is split into two main Terraform deployments:

* build-infrastructure - Fixed VMs which are always running and provide services used by the build agents.
* build-agents - Dynamically scaled VMs which provide the actual build agents.

Each of those directories contains the following:

* xxx-image - A directory containing a Packer template and supporting scripts to build a VM image.
* xxx-deploy - A directory containing a Terraform module and supporting files to deploy a VM image.
* *.tf - Terraform module defining the VM hosts, configuration and instantiating the xxx-deploy modules to deploy instances of the VM images.

## Deployment method

One of my VM hosts has this repository checked out, from there the `build.sh` under each `xxx-image` directory is run to prepare the VM images, then `deploy.sh` in `build-infrastructure` is run, followed by `deploy.sh` from `build-agents`.

From that point, the Terraform state is maintained in local files in that checkout, any further changes are deployed by re-running the appropriate `build.sh` and `deploy.sh` scripts.

The `build.sh` scripts retain each built image under an `xxx-image/builds/` directory and the Terraform modules select the latest version to deploy.

Most of my VM hosts aren't running 24/7 - so the `deploy.sh` scripts use `powerwake` to remotely start them as necessary before attempting to deploy the VM images.

## Scaling

Scaling up VMs in response to Buildkite jobs is accomplished using [buildkite-agent-launcher](https://github.com/solemnwarning/buildkite-agent-launcher), which periodically polls the Buildkite API to check what jobs (steps) are waiting and their agent targeting rules, then remotely powers on VM hosts and starts the VMs to handle the builds.

Scaling back down is accomplished using [powernap](https://github.com/solemnwarning/powernap). The Buildkite agent has the `disconnect-after-idle-timeout` option set to terminate the agent after an idle period, after which (on Linux), the `powernap` daemon will detect the system is idle and shut the VM down after a short delay (the Windows and FreeBSD images currently just have shutdown commands hacked into the buildkite-agent init scripts). The VM hosts also run `powernap` and shut down after a period of no VMs running.

## TODOs

* Automatic deletion of old images
* Scheduled (re)building of images
* Deploy secrets to Windows from Terraform rather than baking into images
* Refactor FreeBSD init script to use standard rc functions
