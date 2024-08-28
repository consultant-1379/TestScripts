#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/../functions


teardown_workload() {
    echo "$FUNCNAME - $(date)"

    WORKLOAD_COMMAND="/opt/ericsson/enmutils/bin/workload"

    if [ ! -z $WORKLOAD_SERVER ]; then
        echo "Enable password-less access to WORKLOAD_SERVER if needed"
        /root/rvb/copy-rsa-key-to-remote-host.exp $WORKLOAD_SERVER root 12shroot

        echo "Perform hard shutdown of workload on WORKLOAD_SERVER"
        TEARDOWN_OPTION=$(ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND -h" | egrep teardown | awk '{print $1}' | egrep tear)
        ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND $TEARDOWN_OPTION"

    else
        echo "No WORKLOAD_SERVER specified in deployment config file, therefore no action being taken"

    fi

}

get_deployment_conf $CLUSTERID
teardown_workload

echo "$0 - script complete - $(date)"

