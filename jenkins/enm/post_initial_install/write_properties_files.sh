#!/bin/bash

BASENAME=`dirname $0`
CLUSTERID=$1

. ${BASENAME}/../functions

get_deployment_conf $CLUSTERID
get_netsims
write_properties_files_for_child_builds
