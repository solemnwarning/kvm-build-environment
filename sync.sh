#!/bin/bash

HOST="root@vmhost01.lan.solemnwarning.net"
DIR="/mnt/vmbuild/kvm-build-environment"

set -e

cd "$(dirname "$0")"

find -name .gitignore -exec perl exclude-gitignore.pl {} \; \
	| xargs rsync -tpr --delete -e ssh . "$HOST:$DIR"
