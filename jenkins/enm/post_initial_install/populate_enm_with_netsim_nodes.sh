#!/bin/bash

BASEDIR=`dirname $0`
NETSIM=$1
CLUSTERID=$2
NODES=$NETSIM-nodes

. ${BASEDIR}/../functions

populate_network() {
    if [ "$ADD_MODEL_ID_DURING_CREATION" = "true" ]
    then
        IDENTITY="--identity"
    fi
    if /opt/ericsson/enmutils/bin/node_populator create $NODES $IDENTITY --verbose
    then
        echo "Executed create $NODES"
    else
        echo "Failed to create $NODES"
        exit 1
    fi
}

add_nodes_to_workload_pool() {
    /opt/ericsson/enmutils/bin/workload add $NODES
}

set -ex

get_deployment_conf $CLUSTERID
populate_network
add_nodes_to_workload_pool
