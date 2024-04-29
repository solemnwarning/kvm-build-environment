#!/bin/bash

set -e

for repo in /srv/git/*
do
	cd "$repo"
	git remote update --prune
done
