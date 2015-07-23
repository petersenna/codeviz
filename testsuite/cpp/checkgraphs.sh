#!/bin/bash

# Check existance of files
if [ ! -e full.graph ]; then
	echo full.graph does not exist
	exit 1
fi
if [ ! -e sub.graph-default ]; then
	echo sub.graph-default does not exist
	exit 1
fi
if [ ! -e sub.graph-trimmed ]; then
	echo sub.graph-trimmed does not exist
	exit 1
fi

# Check differences
FULL=`diff expected-full.graph full.graph | wc -l`
SUB_DEFAULT=`diff expected-sub.graph-default sub.graph-default | wc -l`
SUB_TRIMMED=`diff expected-sub.graph-trimmed sub.graph-trimmed | wc -l`

if [ "$FULL" != "0" ]; then
	echo Line count on full.graph does not match
	exit 1
fi
if [ "$SUB_DEFAULT" != "0" ]; then
	echo Line count on sub.graph-default does not match
	exit 1
fi

if [ "$SUB_TRIMMED" != "0" ]; then
	echo Line count on sub.graph-trimmed does not match
	exit 1
fi

# All good
echo Graphs match expected output
exit 0
