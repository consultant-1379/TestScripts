#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1
PATCH=$2
PATCH_LOCATION=$3
. ${BASEDIR}/../../functions


get_netsim_patch() {
    wget ${PATCH_LOCATION}/${PATCH}
}

copy_patch_to_netsims() {
    scp_to_hosts "$NETSIMS" netsim "${PATCH}" "/netsim/inst"
}

install_patch() {
	execute_on_netsim_pipe "$NETSIMS" ".install patch ${PATCH} force"
}

get_netsims $CLUSTERID
copy_ssh_keys_to_netsims $NETSIMS
get_netsim_patch
copy_patch_to_netsims
install_patch
