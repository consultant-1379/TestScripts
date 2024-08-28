#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/../functions


versant_cc() {
    echo "$FUNCNAME - $(date)"
    DB_NODES=$(litp show -p /deployments/enm/clusters/db_cluster/nodes/ | egrep '/' | egrep -v deployments | cut -f2 -d'/')
    for DB_NODE in $DB_NODES
    do
	echo "Adding versant_cc entry to /etc/crontab on DB Node: $DB_NODE"
    	/root/rvb/bin/ssh_to_vm_and_su_root.exp $DB_NODE 'egrep -v run_versant_consistency.bsh /etc/crontab > /etc/crontab.new; echo "00 02 * * * root /ericsson/enm/dumps/.scripts/run_versant_consistency.bsh" >> /etc/crontab.new; mv -f /etc/crontab.new /etc/crontab '
    done
}

versantTrans() {
    echo "$FUNCNAME - $(date)"
    FILE="/ericsson/enm/dumps/.scripts/VersantTrans.sh"
    if [ ! -f $FILE ]; then
       cp /root/rvb/dumps_dir/VersantTrans.sh ${FILE}
       chmod 755 ${FILE}
    fi
    DB_NODES=$(/opt/ericsson/enminst/bin/vcs.bsh --groups | grep versant | awk '{print $3}')
     for DB_NODE in $DB_NODES
     do
        echo $DB_NODE
        #echo "Adding versant_cc entry to /etc/crontab on DB Node: $DB_NODE"
        /root/rvb/bin/ssh_to_vm_and_su_root.exp $DB_NODE 'egrep -v VersantTrans.sh /etc/crontab > /etc/crontab.new; echo "# */3 * * * * root /ericsson/enm/dumps/.scripts/VersantTrans.sh" >> /etc/crontab.new; mv -f /etc/crontab.new /etc/crontab '
    done
}


cm_nbi() {
    echo "$FUNCNAME - $(date)"
    echo "setting up CM NBI"
    /bin/mkdir -p /ericsson/enm/dumps/cm_event_nbi_client
    HTTP=`cat /etc/hosts | grep haproxy | awk {'print $3'}`
    echo "/usr/bin/python -u /root/rvb/cm_event_nbi_client/cm_events_nbi_kpi_checks.py -m560 -r10000 -c10 -i .5 -k -b -t 60 -z -e \"${HTTP}\" >> /ericsson/enm/dumps/cm_event_nbi_client/cm_events_nbi_kpi_checks.log 2>&1" > ~/cm_nbi
    at -f ~/cm_nbi now
}

check_cm_nbi(){
    echo "$FUNCNAME - $(date)"
    echo "setting up crontab to see if cm_nbi is running"
    echo "0 * * * * root /root/rvb/bin/check_cm_events_nbi.bsh" > /etc/cron.d/check_cm_events_nbi
    chmod 0644 /etc/cron.d/check_cm_events_nbi

}

start_eniq_exports(){
    echo "$FUNCNAME - $(date)"
    IMPEXPSERV_NODE=$(litp show -p /deployments/enm/clusters/svc_cluster/services/impexpserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')
    echo "Turning on ETS_HistoricalCMExportEnabled and ETS_InventoryMoExportEnabled "
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/impexpserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-impexpserv:8080 --name=ETS_HistoricalCMExportEnabled --value=true
   # /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/impexpserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-impexpserv:8080 --name=ETS_InventoryMoExportEnabled --value=true
}
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
        # ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND start HA_01"
        # ssh $WORKLOAD_SERVER "$WORKLOAD_COMMAND start all"

    else
	echo "Seems that WORKLOAD_SERVER variable is empty - needs to exist in deployment conf file - cannot connect to WORKLOAD_SERVER. Nothing more to do."

    fi

}

get_deployment_conf $CLUSTERID
# versant_cc
versantTrans
# cm_nbi
# check_cm_nbi
# start_eniq_exports
# start_workload_profiles

echo "$0 - script complete - $(date)"
