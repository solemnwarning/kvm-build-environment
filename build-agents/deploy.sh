#!/bin/bash

set -e

cd "$(dirname "$0")/"

if [ "$#" -eq 1 ] && [ "$1" = "-y" ]
then
	auto_approve=-auto-approve
elif [ "$#" -eq 0 ]
then
	auto_approve=
else
	echo "Usage: $0 [-y]" 1>&2
	exit 64 # EX_USAGE
fi

powerwake 98:90:96:db:85:40
powerwake 64:00:6a:5d:b3:6e

powerwake -w -t 300 98:90:96:db:85:40
powerwake -w -t 300 64:00:6a:5d:b3:6e

terraform init
terraform apply $auto_approve
