#!/bin/bash

set -e

cd "$(dirname $0)"

timestamp=$(date --utc '+%Y-%m-%dT%H:%M:%SZ')

packer init  -var "output_dir=builds/${timestamp}" winxp-test-agent.pkr.hcl
packer build -var "output_dir=builds/${timestamp}" winxp-test-agent.pkr.hcl

ln -snfv "${timestamp}" "builds/latest"
echo "${timestamp}" > "builds/latest-version"
