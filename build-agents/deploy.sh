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

powerwake vmhost02.lan.solemnwarning.net
powerwake vmhost03.lan.solemnwarning.net
powerwake vmhost04.lan.solemnwarning.net

powerwake -w -t 300 vmhost02.lan.solemnwarning.net
powerwake -w -t 300 vmhost03.lan.solemnwarning.net
powerwake -w -t 300 vmhost04.lan.solemnwarning.net

terraform apply $auto_approve
