#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/../functions

start_workload_profiles() {
    echo "$FUNCNAME - $(date)"

    WORKLOAD_COMMAND="/opt/ericsson/enmutils/bin/workload"
    NODE_FILES_DIR="/opt/ericsson/enmutils/etc/nodes/"

    if [ ! -z $WORKLOAD_SERVER ]; then

        echo "Setup nodes folder on WORKLOAD_SERVER"
        ssh $WORKLOAD_SERVER "[[ -d $NODE_FILES_DIR ]] && rm -rf $NODE_FILES_DIR; mkdir -p $NODE_FILES_DIR"

        echo "Copy all non-failed node populator-parsed files from LMS to WORKLOAD_SERVER"
        for FILE in $(ls $NODE_FILES_DIR | egrep -v failed)
        do
                scp -r $NODE_FILES_DIR/$FILE $WORKLOAD_SERVER:$NODE_FILES_DIR/
        done


        echo "Add nodes to workload pool on WORKLOAD_SERVER"
        for FILE in $(ls $NODE_FILES_DIR | egrep -v failed)
        do
                echo "Add $FILE to workload pool"
                ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND add $NODE_FILES_DIR/$FILE"
        done

        echo "Start the workload on WORKLOAD_SERVER - all profiles"
        ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND start all"

    else
	echo "Seems that WORKLOAD_SERVER variable is empy - needs to exist in deployment conf file - cannot connect to WORKLOAD_SERVER. Nothing more to do."

    fi

}

get_deployment_conf $CLUSTERID
start_workload_profiles

echo "$0 - script complete - $(date)"
