#!/bin/bash

set -eo pipefail

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

log=$(mktemp)

if [ -n "$quiet" ]
then
	make > "${log}" 2>&1 || (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
else
	make |& tee "${log}"
fi

mv "${log}" "builds/latest/build.log"
