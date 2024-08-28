#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/functions

set_pib_properties_for_pm(){
    echo "$FUNCNAME - $(date)"
    PMSERV_NODE=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')

    echo "Changing Sym link retention to 15 mins"
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicSymbolicLinkRetentionPeriodInMinutes --value=15
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicEventsSymbolicLinkRetentionPeriodInMinutes --value=15
}

integrate_eniq(){
    echo "$FUNCNAME - $(date)"
    /opt/ericsson/ENM_ENIQ_Integration/eniq_enm_integration.py eniq_oss_1 1.1.1.1
    /opt/ericsson/ENM_ENIQ_Integration/eniq_enm_integration.py events_oss_2 2.2.2.2
}

latest_torutils(){
    /opt/ericsson/enmutils/.deploy/update_enmutils_rpm -l
}

manage_nodes(){
    /opt/ericsson/enmutils/bin/node_populator manage rvb-network
}

check_sync_status(){
    echo "$FUNCNAME - $(date)"
    echo "Sleeping for 5 mins to check if sync is actually in progress"
    sleep 300
    /opt/ericsson/enmutils/bin/network sync-status --groups
}

set_pm_sync(){
    /opt/ericsson/enmutils/bin/network netsync pm
}

set_fm_sync(){
    /opt/ericsson/enmutils/bin/network netsync fm
}

set_cm_sync(){
    /opt/ericsson/enmutils/bin/network netsync cm
}

get_node_ip_addresses() {
    echo "$FUNCNAME - $(date)"
    # Get IP addresses of Nodes
    /opt/ericsson/enmutils/bin/cli_app 'cmedit get * CppConnectivityInformation.ipAddress' | egrep '^FDN|^ip' | paste - - > /ericsson/enm/dumps/nodes.cpp.ipaddress
    /opt/ericsson/enmutils/bin/cli_app 'cmedit get * ComConnectivityInformation.ipAddress' | egrep '^FDN|^ip' | paste - - > /ericsson/enm/dumps/nodes.com.ipaddress

}
cm_nbi(){
    echo "$FUNCNAME - $(date)"
    echo "setting up CM NBI"
    mkdir -p /ericsson/enm/dumps/cm_event_nbi_client
    HTTP=`cat /etc/hosts | grep haproxy | awk {'print $3'}`
    echo "/usr/bin/python -u /root/rvb/cm_event_nbi_client/cm_events_nbi_kpi_checks.py -m560 -r10000 -c10 -i .5 -k -b -t 60 -e \"${HTTP}\" >> /ericsson/enm/dumps/cm_event_nbi_client/cm_events_nbi_kpi_checks.log 2>&1" > ~/cm_nbi
    at -f ~/cm_nbi now
}

pm_nbi(){
echo "00,15,30,45 * * * * root /ericsson/enm/dumps/.scripts/sftpExpect.sh" > /etc/cron.d/pm_nbi
/root/rvb/bin/ssh_to_vm_and_su_root.exp scp-1-scripting 'echo "05,20,35,50 * * * * root /ericsson/enm/dumps/.scripts/files.sh" > /etc/cron.d/pm_nbi'

}

versant_cc(){
    echo "$FUNCNAME - $(date)"
    /root/rvb/bin/ssh_to_vm_and_su_root.exp db-1 ' echo "00 02 * * * root /ericsson/enm/dumps/.scripts/run_versant_consistency.bsh" >> /etc/crontab '
    /root/rvb/bin/ssh_to_vm_and_su_root.exp db-2 ' echo "00 02 * * * root /ericsson/enm/dumps/.scripts/run_versant_consistency.bsh" >> /etc/crontab '
}

update_pib_properties_for_pm(){

    echo "$FUNCNAME - $(date)"
    PMSERV_NODE=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')

    echo "Changing Sym link retention to 15 mins"
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicSymbolicLinkRetentionPeriodInMinutes --value=15
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicEventsSymbolicLinkRetentionPeriodInMinutes --value=15

    echo "Enabling CTUM file collection for SGSNS"
    /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=ctumCollectionEnabled --value=true

    if [ 5${CLUSTERID} == "300" ] || [ 5${CLUSTERID} == "310" ]; then
    #TODO Remove these PM settings when Thin Luns gone
    #Setting PM Retention to 2 hours
        /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicStatisticalFileRetentionPeriodInMinutes --value=180
        /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=pmicStatisticalFileDeletionIntervalInMinutes --value=60
        /ericsson/pib-scripts/etc/config.py update --app_server_address=$(litp show -p /deployments/enm/clusters/svc_cluster/services/pmserv | egrep node_list | awk '{print $NF}' | awk -F',' '{print $1}')-pmserv:8080 --name=fileRecoveryHoursInfo --value=3
    fi
}

start_workload_profiles(){
    echo "$FUNCNAME - $(date)"
    if [ ! -z $1 ]; then
        if [ ! -z $2 ]; then
            echo "Scheduling profile group $1 to be started $2 minutes from now - can check with \"atq\" and \"at -c job_id\" commands"
            echo "/opt/ericsson/enmutils/bin/workload start $1" > ~/.$1
            at -f ~/.$1 now + $2 minutes
	else
            echo "Starting profile group $1 now "
            /opt/ericsson/enmutils/bin/workload start $1
	fi
    else
        echo "No profiles given, skipping"
    fi
}

get_deployment_conf $CLUSTERID
set_pib_properties_for_pm
integrate_eniq
#manage_nodes
check_sync_status
set_pm_sync
set_fm_sync
set_cm_sync
cm_nbi
check_sync_status
latest_torutils

#AP
start_workload_profiles $AP_PROFILES

#FM
start_workload_profiles $FM_PROFILES
sleep 180

#FMX
start_workload_profiles $FMX_PROFILES

#PM
start_workload_profiles $PM_PRE_SYNC_PROFILES 1
start_workload_profiles $PM_POST_SYNC_PROFILES 210

#NHM
start_workload_profiles $NHM_SETUP 260
start_workload_profiles $NHM_PROFILES 300

#SHM
start_workload_profiles $SHM_PROFILES

#SECUI
start_workload_profiles $SECUI_PROFILES

#NETEX
start_workload_profiles $NETEX_PROFILES

#DOC
start_workload_profiles $DOC_PROFILES

#UTILITIES
start_workload_profiles $UTILITIES_PROFILES

#LOGVIEWER
start_workload_profiles $LOGVIEWER_PROFILES

#CM
start_workload_profiles $CM_PROFILES

#EXPORT
start_workload_profiles $EXPORT_PROFILES 120

#IMPORT
start_workload_profiles $IMPORT_PROFILES 120
start_workload_profiles $IMPORT_07

#CM_CLI
start_workload_profiles $CM_CLI_PROFILES 360

#TOP
start_workload_profiles $TOP_PROFILES 250

#DELTA
[[ ! -z $CM_DELTA_PROFILES ]] && start_workload_profiles $CM_DELTA_PROFILES 300

#NODESEC
start_workload_profiles $NODESEC_PROFILES

#CM KPIs
echo "/root/rvb/bin/stkpi_CMCLI_01.sh -n -p > /ericsson/enm/dumps/stkpi_CMCLI_01.log" > ~/.CMCLI_01
echo "/root/rvb/bin/stkpi_CMCLI_01.sh -s >> /ericsson/enm/dumps/stkpi_CMCLI_01.log" >> ~/.CMCLI_01
at -f ~/.CMCLI_01 now + 270 minutes


#MONITORING
start_workload_profiles $ESM_PROFILES

#AMOS
start_workload_profiles $AMOS_PROFILES

#EM
start_workload_profiles $EM_PROFILES

#MISC
get_node_ip_addresses
atq
echo "$0 - script complete - $(date)"
