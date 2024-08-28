#!/bin/bash

BASEDIR=`dirname $0`
NETSIM=$1
FETCH_DIR=/var/rvb/network/$NETSIM
NODES=$NETSIM-nodes

create_network_dir_for_fetch() {
    echo "$FUNCNAME - $(date)"
    mkdir -p $FETCH_DIR
    rm -rf $FETCH_DIR/*
}

fetch_arne_xmls_from_netsim() {
    echo "$FUNCNAME - $(date)"
    /opt/ericsson/enmutils/bin/netsim fetch $NETSIM $FETCH_DIR
}   

parse_network() {
    echo "$FUNCNAME - $(date)"
    /opt/ericsson/enmutils/bin/node_populator parse -s $NODES /var/rvb/network/$NETSIM
}

set -ex
create_network_dir_for_fetch
fetch_arne_xmls_from_netsim
parse_network
echo "Operations Completed - $(date)"
