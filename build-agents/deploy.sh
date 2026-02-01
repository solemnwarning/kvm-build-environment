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

rsync -rLtv --delete --delete-before output/vmhost01/          /srv/vm-templates/build-agents/ &
rsync -rLtv --delete --delete-before output/vmhost02/ vmhost02:/srv/vm-templates/build-agents/ &
rsync -rLtv --delete --delete-before output/vmhost03/ vmhost03:/srv/vm-templates/build-agents/ &
rsync -rLtv --delete --delete-before output/vmhost04/ vmhost04:/srv/vm-templates/build-agents/ &

wait -nf
wait -nf
wait -nf
wait -nf
