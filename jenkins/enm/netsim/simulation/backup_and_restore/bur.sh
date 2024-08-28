#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/../../../functions

get_netsims $CLUSTERID
write_properties_files_for_child_builds
