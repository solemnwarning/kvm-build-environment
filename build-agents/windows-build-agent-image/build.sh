#!/bin/bash

set -e

# Windows evals are good for 180 days before needing to be activated, so we
# rebuild the base Windows image if 120 days has passed since it was built.
MAX_WINDOWS_IMAGE_AGE="$[60 * 60 * 24 * 120]"

timestamp=$(date --utc '+%Y-%m-%dT%H:%M:%SZ')

cd "$(dirname "$0")/"

if [ ! -e "packer-Win2022/output-qemu/Win2022_20324.qcow2" ] \
	|| [ "$(( $(date +"%s") - $(stat -c "%Y" "packer-Win2022/output-qemu/Win2022_20324.qcow2") ))" -gt "$MAX_WINDOWS_IMAGE_AGE" ]
then
	if [ -e "packer-Win2022/output-qemu/" ]
	then
		rm -rf "packer-Win2022/output-qemu.old"
		mv "packer-Win2022/output-qemu" "packer-Win2022/output-qemu.old"
	fi
	
	cd "packer-Win2022/"
	
	if [ ! -e "virtio-win-0.1.229.iso" ]
	then
		wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.229-1/virtio-win-0.1.229.iso
	fi
	
	packer build -only=qemu -var "disk_size=120G" win2022-gui.json
	
	cd "../"
fi

if [ ! -e "msvc-build-tools/msvc-build-tools.qcow2" ]
then
	packer init msvc-build-tools.pkr.hcl
	packer build msvc-build-tools.pkr.hcl
fi

packer init  -var-file="../windows-build-agent.pkrvars.hcl" -var "output_dir=builds/${timestamp}" windows-build-agent.pkr.hcl
packer build -var-file="../windows-build-agent.pkrvars.hcl" -var "output_dir=builds/${timestamp}" windows-build-agent.pkr.hcl

ln -snfv "${timestamp}" "builds/latest"
echo "${timestamp}" > "builds/latest-version"
