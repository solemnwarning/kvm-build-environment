#!/bin/bash

CCACHE_ROOT=/srv/ccache-cache/
MIN_FREE_PERCENT=80
N_FILES_AT_A_TIME=10

set -eo pipefail

tmpfile_a="$(mktemp)"
tmpfile_b="$(mktemp)"

if [ "$(df -P "$CCACHE_ROOT" | tail -n 1 | awk '{print 0+$5}')" -gt "$MIN_FREE_PERCENT" ]
then
	# Get a listing of all files in the ccache directory sorted from
	# least-recently-accessed to most-recently-accessed.
	find "$CCACHE_ROOT" -type f -printf '%A@+%p\0' | sort -zn | cut -z -d+ -f2 > "$tmpfile_a"
	
	while [ "$(df -P "$CCACHE_ROOT" | tail -n 1 | awk '{print 0+$5}')" -gt "$MIN_FREE_PERCENT" ]
	do
		# Delete the first n files from the list.
		head -zn "$N_FILES_AT_A_TIME" "$tmpfile_a" | xargs -0 -- rm -f
		
		# Remove the first n files from the list for the next loop.
		tail -zn +"$N_FILES_AT_A_TIME" "$tmpfile_a" > "$tmpfile_b"
		cat "$tmpfile_b" > "$tmpfile_a"
	done
fi

rm -f "$tmpfile_a"
rm -f "$tmpfile_b"
