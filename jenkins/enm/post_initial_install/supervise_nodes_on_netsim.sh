#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1
NETSIM=$2
NODES=$NETSIM-nodes

. ${BASEDIR}/../functions

cm_supervise_nodes() {
    echo "CM_SYNC is $CM_SYNC"
    if [ "$CM_SYNC" == "true" ]; then
        /opt/ericsson/enmutils/bin/cli_app "cmedit set * CmNodeHeartbeatSupervision.active!=true active=true"
    fi
}

pm_supervise_nodes() {
	echo "PM_ENABLED is $PM_ENABLED"
	if [ "$PM_ENABLED" == "true" ]; then
        /opt/ericsson/enmutils/bin/cli_app "cmedit set * PmFunction.pmEnabled!=true pmEnabled=true"
	fi
}

fm_supervise_nodes() {
	echo "FM_ENABLED is $FM_ENABLED"
	if [ "$FM_ENABLED" == "true" ]; then
        /opt/ericsson/enmutils/bin/cli_app "alarm enable *"
	fi
}

get_deployment_conf $CLUSTERID
cm_supervise_nodes
pm_supervise_nodes
fm_supervise_nodes
