#!/bin/bash

set -eo pipefail

# Windows evals are good for 180 days before needing to be activated, so we
# rebuild the base Windows image if 120 days has passed since it was built.
MAX_WINDOWS_IMAGE_AGE="$[60 * 60 * 24 * 120]"

if [ "$#" -eq 1 ] && [ "$1" = "-q" ]
then
	quiet=yes
elif [ "$#" -eq 0 ]
then
	quiet=
else
	echo "Usage: $0 [-q]" 1>&2
	exit 64 # EX_USAGE
fi

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
	
	log="$(mktemp)"
	
	if [ -n "$quiet" ]
	then
		packer build -timestamp-ui -only=qemu -var "disk_size=120G" win2022-gui.json > "${log}" 2>&1 \
			|| (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
	else
		packer build -timestamp-ui -only=qemu -var "disk_size=120G" win2022-gui.json |& tee "${log}"
	fi
	
	mv "${log}" "output-qemu/build.log"
	
	cd "../"
fi

if [ ! -e "msvc-build-tools/msvc-build-tools.qcow2" ]
then
	packer init msvc-build-tools.pkr.hcl
	
	log="$(mktemp)"
	
	if [ -n "$quiet" ]
	then
		packer build -timestamp-ui msvc-build-tools.pkr.hcl > "${log}" 2>&1 \
			|| (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
	else
		packer build -timestamp-ui msvc-build-tools.pkr.hcl |& tee "${log}"
	fi
	
	mv "${log}" "msvc-build-tools/build.log"
fi

packer init  -var-file="../windows-build-agent.pkrvars.hcl" -var "output_dir=builds/${timestamp}" windows-build-agent.pkr.hcl

log="$(mktemp)"

if [ -n "$quiet" ]
then
	packer build -timestamp-ui -var-file="../windows-build-agent.pkrvars.hcl" -var "output_dir=builds/${timestamp}" windows-build-agent.pkr.hcl  > "${log}" 2>&1 \
		|| (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
else
	packer build -timestamp-ui -var-file="../windows-build-agent.pkrvars.hcl" -var "output_dir=builds/${timestamp}" windows-build-agent.pkr.hcl |& tee "${log}"
fi

mv "${log}" "builds/${timestamp}/build.log"

ln -snf "${timestamp}" "builds/latest"
echo "${timestamp}" > "builds/latest-version"
