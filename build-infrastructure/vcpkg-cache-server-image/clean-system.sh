#!/bin/sh

set -e

# Remove downloaded .deb files
apt-get clean

# Delete cloud-init state.
cloud-init clean

find \
	/var/cache/apt \
	/var/lib/apt \
	-mindepth 1 -print -delete

# Remove instance-specific files: we want this image to be as "impersonal" as
# possible.
find \
	/var/lib/dhcp \
	/var/log \
	-mindepth 1 -print -delete

rm -vf \
	/etc/network/interfaces.d/50-cloud-init.cfg \
	/etc/adjtime \
	/etc/hostname \
	/etc/hosts \
	/etc/ssh/*key* \
	/var/cache/ldconfig/aux-cache \
	/var/lib/systemd/random-seed \
	~/.bash_history

# From https://www.freedesktop.org/software/systemd/man/machine-id.html:
# For operating system images which are created once and used on multiple
# machines, [...] /etc/machine-id should be an empty file in the generic file
# system image.
truncate -s 0 /etc/machine-id

# Recreate some useful files.
touch /var/log/lastlog
chown root:utmp /var/log/lastlog
chmod 664 /var/log/lastlog

mkdir /var/log/apache2/
chown root:adm /var/log/apache2/
chmod 0700 /var/log/apache2/

# Free all unused storage block. This makes the final image smaller.
fstrim --all --verbose
