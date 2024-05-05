#!/bin/bash

set -e

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

cd "$(dirname "$0")/"

terraform init
terraform validate
terraform apply $auto_approve
