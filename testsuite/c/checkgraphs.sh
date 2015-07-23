#!/bin/bash

# Check existance of files
if [ ! -e full.graph ]; then
	echo full.graph does not exist
	exit 1
fi
if [ ! -e sub.graph ]; then
	echo sub.graph does not exist
	exit 1
fi

# Check differences
FULL=`diff expected-full.graph full.graph | wc -l`
SUB=`diff expected-sub.graph sub.graph | wc -l`

if [ "$FULL" != "0" ]; then
	echo Line count on full.graph does not match
	exit 1
fi
if [ "$SUB" != "0" ]; then
	echo Line count on sub.graph does not match
	exit 1
fi

# All good
echo Graphs match expected output
exit 0
