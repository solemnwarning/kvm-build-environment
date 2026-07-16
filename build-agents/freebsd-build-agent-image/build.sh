#!/bin/bash

set -eo pipefail

# Packer's handling of xz-compressed images is utterly idiotic - at some point during the
# decompression and/or verification, it winds up reading in the entire file from disk a SINGLE byte
# at a time, which unsurprisingly, takes ~15 minutes to process the ~800MB FreeBSD base image on my
# machine.
#
# To work around this, we download and decompress the image ourselves, then we give the
# uncompressed image to Packer and all carries on more reasonably.
#
# FREEBSD_IMG_NAME    Name that the xz-compressed image will decompress to.
# FREEBSD_IMG_URL     URL of the xz-compressed image.
# FREEBSD_IMG_SHA256  SHA-256 checksum of the UNCOMPRESSED image.

# FREEBSD_IMG_NAME="FreeBSD-14.3-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2"
# FREEBSD_IMG_URL="https://download.freebsd.org/ftp/releases/VM-IMAGES/14.3-RELEASE/amd64/Latest/FreeBSD-14.3-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2.xz"
# FREEBSD_IMG_SHA256="5082c6c71dccef65c7229d17020a0e66d9785b3a7bf116350b6b62dc2207697e"

FREEBSD_IMG_NAME="FreeBSD-15.1-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2"
FREEBSD_IMG_URL="https://download.freebsd.org/releases/VM-IMAGES/15.1-RELEASE/amd64/Latest/FreeBSD-15.1-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2.xz"
FREEBSD_IMG_SHA256="a5289152ea5b9145cc89e58ab83186173e43b5ba1ed4e9358b8f357241476229"

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

cd "$(dirname "$0")/"

if ! echo "${FREEBSD_IMG_SHA256}  ${FREEBSD_IMG_NAME}" | sha256sum -c
then
	wget -O "$(basename "$FREEBSD_IMG_URL")" "$FREEBSD_IMG_URL"
	unxz "$(basename "$FREEBSD_IMG_URL")"
	
	echo "${FREEBSD_IMG_SHA256}  ${FREEBSD_IMG_NAME}" | sha256sum -c
fi

timestamp=$(date --utc '+%Y-%m-%dT%H:%M:%SZ')
log=$(mktemp)

packer init  -var "output_dir=builds/${timestamp}" freebsd-build-agent.pkr.hcl

if [ -n "$quiet" ]
then
	packer build -timestamp-ui -var "output_dir=builds/${timestamp}" -var "iso_url=$FREEBSD_IMG_NAME" -var "iso_checksum=$FREEBSD_IMG_SHA256" freebsd-build-agent.pkr.hcl > "${log}" 2>&1 \
		|| (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
else
	packer build -timestamp-ui -var "output_dir=builds/${timestamp}" -var "iso_url=$FREEBSD_IMG_NAME" -var "iso_checksum=$FREEBSD_IMG_SHA256" freebsd-build-agent.pkr.hcl |& tee "${log}"
fi

mv "${log}" "builds/${timestamp}/build.log"

ln -snf "${timestamp}" "builds/latest"
echo "${timestamp}" > "builds/latest-version"
