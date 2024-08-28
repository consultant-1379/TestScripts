#!/bin/bash

BASENAME=`dirname $0`
CLUSTERID=$1

. ${BASENAME}/functions

get_lms_ip_address() {
    LMS=`wget -q -O - --no-check-certificate "https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId=${CLUSTERID}&tunnel=true" | awk -F',' '{print $1}' | awk -F':' '{print $2}' | sed -e "s/\"//g" -e "s/ //g"`
}

get_svc_blades() {
    COMMAND_OUTPUT=$(execute_on_hosts $LMS root "getent hosts | tr -s ' ' | cut -d ' ' -f 2")
    SVC_BLADES=$(echo $COMMAND_OUTPUT | egrep 'svc-[0-9]+$')
}

_execute_on_blade() {
    BLADE=$1
    COMMAND=$2
    execute_on_hosts $LMS root "/root/rvb/bin/ssh_to_vm_and_su_root.exp $BLADE '$COMMAND'"
}

_execute_on_active_db_node_as_versant() {
    COMMAND=$1
    execute_on_hosts $LMS root "/root/rvb/bin/ssh_to_vm_and_su_root.exp db1-service \"su -c '$COMMAND' - versant\""
}

_execute_on_active_db_node_as_root() {
    COMMAND=$1
    execute_on_hosts $LMS root "/root/rvb/bin/ssh_to_vm_and_su_root.exp db1-service '$COMMAND'"
}

stop_puppet() {
    execute_on_hosts $LMS root "service puppet stop"
    for SVC_BLADE in $SVC_BLADES
    do
        _execute_on_blade $SVC_BLADE 'service puppet stop'
    done
}

_wait_until_all_svcs_are_stopped() {
    _execute_on_blade 'svc-1' 'for SVC in $(hasys -list); do hasys -wait $SVC SysState EXITED ; done'
}

_wait_until_all_svcs_are_started() {
    _execute_on_blade 'svc-1' 'for SVC in $(hasys -list); do hasys -wait $SVC SysState RUNNING ; done'
}

stop_all_svc_vms() {
    _execute_on_blade 'svc-1' 'hastop -all'
    _wait_until_all_svcs_are_stopped
}

freeze_the_versant_cluster() {
    _execute_on_active_db_node_as_root "hagrp -freeze Grp_CS_db_cluster_versant_clustered_service_1"
}

remove_and_recreate_the_database() {
    _execute_on_active_db_node_as_versant "source /ericsson/versant/bin/envsettings.sh && stopdb -f dps_integration && removedb -f dps_integration && createdb -i -il dps_integration && startdb dps_integration"
    sleep 10
}

upload_the_schema() {
    _execute_on_active_db_node_as_root "cd /opt/ericsson/ERICdpsupgrade/sut/; sh sut.sh"
}

unfreeze_the_versant_cluster() {
    _execute_on_active_db_node_as_root "hagrp -unfreeze Grp_CS_db_cluster_versant_clustered_service_1"
}

gabconfig_on_svc() {
    _execute_on_blade 'svc-1' 'gabconfig -x'
}

start_all_svc_vms() {
    for SVC_BLADE in $SVC_BLADES
    do
        _execute_on_blade $SVC_BLADE 'hastart'
    done
    _wait_until_all_svcs_are_started
}

start_puppet() {
    for SVC_BLADE in $SVC_BLADES
    do
        _execute_on_blade $SVC_BLADE 'service puppet start'
    done
    execute_on_hosts $LMS root 'service puppet start'
}

get_lms_ip_address
get_svc_blades
stop_puppet
stop_all_svc_vms
freeze_the_versant_cluster
remove_and_recreate_the_database
upload_the_schema
unfreeze_the_versant_cluster
gabconfig_on_svc
start_all_svc_vms
start_puppet
