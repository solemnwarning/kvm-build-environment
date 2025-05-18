#!/bin/bash

set -e

step_name="$1"
shift

cd "$step_name"

timestamp=$(date --utc '+%Y-%m-%dT%H:%M:%SZ')

packer init "${step_name}.pkr.hcl"

mkdir -p builds/
packer build -timestamp-ui -var "output_dir=builds/${timestamp}" "$@" "${step_name}.pkr.hcl"
ln -snf "$timestamp" builds/latest
echo "$timestamp" > builds/latest-version

test -e .first-successful-build || touch .first-successful-build
touch .last-successful-build
