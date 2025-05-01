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

timestamp=$(date --utc '+%Y-%m-%dT%H:%M:%SZ')
log=$(mktemp)

packer init  -var "output_dir=builds/${timestamp}" ipxwrapper-test-agent.pkr.hcl

if [ -n "$quiet" ]
then
	packer build -timestamp-ui -var "output_dir=builds/${timestamp}" ipxwrapper-test-agent.pkr.hcl > "${log}" 2>&1 \
		|| (status=$?; cat "${log}"; rm -f "${log}"; exit $status)
else
	packer build -timestamp-ui -var "output_dir=builds/${timestamp}" ipxwrapper-test-agent.pkr.hcl |& tee "${log}"
fi

mv "${log}" "builds/${timestamp}/build.log"

ln -snf "${timestamp}" "builds/latest"
echo "${timestamp}" > "builds/latest-version"
