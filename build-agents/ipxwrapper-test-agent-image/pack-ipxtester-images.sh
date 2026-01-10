#!/bin/bash
# Build QCOW2 disk image containing a btrfs-formatted filesystem containing
# the ipxtester images for attaching to the IPXWrapper test VM.

set -eE

DISK_SIZE="120G"

IPXTESTER_IMAGES=(
    "ipxtester-images/ipxtest-director-2024-07-03"
    "ipxtester-images/ipxtest-winXPx86-2023-09-11"
    "ipxtester-images/ipxtest-win7x64-2023-09-12"
    "ipxtester-images/ipxtest-win81x86-2023-09-11"
    "ipxtester-images/ipxtest-win10x64-2025-07-27"
    "ipxtester-images/ipxtest-win11x64-2025-07-31"
    "ipxtester-images/ipxtest-win98-2024-11-03"
)

IPXTESTER_INI="ipxtester.ini"

# We generate a hash of the file listing and sizes/modification times of all files which contribute
# to the image for versioning/detecting changes.

hash="$(find "${IPXTESTER_IMAGES[@]}" "$IPXTESTER_INI" "$0" -print0 \
	| sort -z \
	| xargs -0 ls -ld --time-style=long-iso \
	| sha256sum \
	| cut -d' ' -f1)"

# Check if an image for this version already exists
matching_image=( "$(dirname "$0")/builds/ipxwrapper-test-images/"*-"${hash}.qcow2" )

if [ -e "${matching_image[0]}" ]
then
	echo "Existing image found: $matching_image"
	exit
fi

# Build a list of old images to delete on success
old_images=( "$(dirname "$0")/builds/ipxwrapper-test-images/"*-*.qcow2 )

target_image_name="$(date --utc '+%Y-%m-%dT%H:%M:%SZ')-${hash}.qcow2"
target_image_path="$(dirname "$0")/builds/ipxwrapper-test-images/${target_image_name}"

echo "Buildimg image: ${target_image_name}"

# Find a free NBD device to attach the image to

modprobe nbd

nbd_dev=""

for d in /sys/block/nbd[0-9]*;
do
	if [ -z "$nbd_dev" ] && [ -r "$d" ] && [ ! -s "$d/pid" ]
	then
		nbd_dev="/dev/${d##*/}"
	fi
done

if [ -z "$nbd_dev" ]
then
	echo "No free NBD devices" 1>&2
	exit 1
fi

echo "Using NBD device ${nbd_dev}"

tmpdir=
img_created=
img_attached=
img_mounted=

tmpdir="$(mktemp -d)"

function cleanup()
{
	if [ -n "$img_mounted" ]
	then
		umount "${tmpdir}" || true
	fi
	
	if [ -n "$img_attached" ]
	then
		qemu-nbd -d "$nbd_dev" || true
	fi
	
	if [ -n "$tmpdir" ]
	then
		rmdir "$tmpdir" || true
	fi
}

mkdir -p "$(dirname "$target_image_path")"

trap 'if [ -n "$img_created" ]; then rm "$target_image_path" || true; fi' ERR
trap 'cleanup' EXIT

qemu-img create -f qcow2 "$target_image_path" "$DISK_SIZE"
img_created=1

qemu-nbd -c "$nbd_dev" "$target_image_path"
img_attached=1

parted -s -a optimal "$nbd_dev" mklabel gpt
parted -s -a optimal "$nbd_dev" mkpart primary btrfs 0% 100%
partprobe "$nbd_dev"
mkfs.btrfs -f -L ipxtester-data "${nbd_dev}p1"

mount "${nbd_dev}p1" "${tmpdir}/"
img_mounted=1

mkdir "${tmpdir}/images/"
mkdir "${tmpdir}/tmp/"

for image in "${IPXTESTER_IMAGES[@]}"; do
	cp -rv "$image" "${tmpdir}/images/"
done

cp -v "$IPXTESTER_INI" "${tmpdir}/ipxtester.ini"

img_mounted=
umount "${tmpdir}"

img_attached=
qemu-nbd -d "$nbd_dev"

echo "Built image: ${target_image_name}"

ln -snf "${target_image_name}" "builds/ipxwrapper-test-images/latest"
echo "${target_image_name}" > "builds/ipxwrapper-test-images/latest-version"

echo "Deleting old images..."
rm -fv "${old_images[@]}"
