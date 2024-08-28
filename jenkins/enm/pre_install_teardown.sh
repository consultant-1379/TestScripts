#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/functions

teardown_enm() {
    if [ -d /software/autoDeploy ]
    then
        SED_FILE=$(ls -t /software/autoDeploy/ | while read file; do if grep -q -m 1 'SED Template' /software/autoDeploy/$file; then echo /software/autoDeploy/$file; exit 0; fi; done)
        /opt/ericsson/enminst/bin/teardown.sh -y --sed $SED_FILE --command=clean_all
    fi
}

workload_teardown() {
    pkill -f /opt/ericsson/enmutils/.env/bin/daemon
    rm -rf /tmp/enmutils/daemon/profiles/
    if [ -e /opt/ericsson/enmutils/bin/persistence ]
    then
        /opt/ericsson/enmutils/bin/persistence clear force
    fi
}
    
teardown_workload() {
    if [ ! -z $WORKLOAD_SERVER ]; then
        /root/rvb/copy-rsa-key-to-remote-host.exp $WORKLOAD_SERVER root 12shroot
        ssh $WORKLOAD_SERVER "$(typeset -f workload_teardown); workload_teardown"
    fi
    workload_teardown
}

get_deployment_conf $CLUSTERID
teardown_enm
teardown_workload
