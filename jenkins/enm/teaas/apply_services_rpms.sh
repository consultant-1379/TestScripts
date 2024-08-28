#!/bin/bash

RPM_BACKUP_PARENT_DIR='/var/tmp/rpm_backup'
ENM_SERVICES_DIR='/var/www/html/ENM_services'

usage() {
    echo 'Script to deploy service rpm(s) on service group(s)'
    echo "Usage: $0 -r 'rpm_urls' -g 'service_groups' -i jira_id"
    echo 
    echo ' where'
    echo '     -r    rpm_urls, a space separated list of URLs for the RPMs within quotes'
    echo '     -g    service_groups, a space separated list of service groups within quotes.'
    echo '           Full SG name or short form are both acceptable.'
    echo '           e.g. Grp_CS_svc_cluster_shmcoreserv or shmcoreserv'
    echo '     -i    jira_id, the ID of the relevant Jira Issue. e.g. CIP-12345'
    echo
    exit 1
}

create_backup_directory() {
    JIRA_ID=$1
    TIMESTAMP=$(date '+%Y_%m_%d_%H:%M:%S')
    BACKUP_DIR=$RPM_BACKUP_PARENT_DIR/$JIRA_ID/$TIMESTAMP
    mkdir -p "$BACKUP_DIR"
    echo "$BACKUP_DIR" 
}

get_rpm_names_from_rpm_url_list() {
    RPM_URL_LIST="$1"
    RPM_NAMES=''
    for RPM_URL in $RPM_URL_LIST
    do
        RPM_NAME=$(echo "${RPM_URL}" | awk -F"/" '{print $NF}' | awk -F '-' '{print $1}')
        RPM_NAMES="$RPM_NAMES $RPM_NAME"
    done
    echo "$RPM_NAMES"
}

move_old_rpms_to_backup_directory() {
    BACKUP_DIR=$1
    RPM_NAMES="$2"
    SOURCE_FILE_PATHS=''
    for RPM_NAME in $RPM_NAMES
    do
        SOURCE_FILE_PATH="$ENM_SERVICES_DIR/$RPM_NAME*"
        SOURCE_FILE_PATHS="$SOURCE_FILE_PATHS $SOURCE_FILE_PATH"
    done
    mv --verbose -t $BACKUP_DIR $SOURCE_FILE_PATHS
}

move_old_rpms_to_enm_services_dir() {
    BACKUP_DIR=$1
    mv --verbose -t $ENM_SERVICES_DIR $BACKUP_DIR/*
}

load_new_rpms_into_repo() {
    cd $ENM_SERVICES_DIR
    if wget $RPM_URL_LIST
    then
        createrepo .
        yum clean all
        return 0
    else
        return 1
    fi
}

backup_old_rpms_and_load_new_rpms_into_repo() {
    RPM_URL_LIST="$1"
    BACKUP_DIR=$(create_backup_directory $JIRA_ID)
    RPM_NAMES=$(get_rpm_names_from_rpm_url_list "$RPM_URL_LIST")
    move_old_rpms_to_backup_directory $BACKUP_DIR "$RPM_NAMES"
    if ! load_new_rpms_into_repo $RPM_URL_LIST
    then
        move_old_rpms_to_enm_services_dir $BACKUP_DIR
        return 1
    fi
    return 0
}

get_service_group_regex() {
    SHORT_NAME_SERVICE_GROUP_LIST="$1"
    SERVICE_GROUP_LIST_REGEX=''
    for SERVICE_GROUP in $SHORT_NAME_SERVICE_GROUP_LIST
    do
        if [ -z $SERVICE_GROUP_LIST_REGEX ]
        then
            SERVICE_GROUP_LIST_REGEX="_$SERVICE_GROUP "
        else
            SERVICE_GROUP_LIST_REGEX="$SERVICE_GROUP_LIST_REGEX|_$SERVICE_GROUP "
        fi
    done
    echo "$SERVICE_GROUP_LIST_REGEX"
}

get_full_name_service_group_list() {
    SHORT_NAME_SERVICE_GROUP_LIST="$1"
    SERVICE_GROUP_REGEX=$(get_service_group_regex "$SHORT_NAME_SERVICE_GROUP_LIST")
    FULL_NAME_SERVICE_GROUP_LIST=$(/opt/ericsson/enminst/bin/vcs.bsh --groups | egrep "$SERVICE_GROUP_REGEX" | awk '{print $2}' | sort | uniq)
    echo "$FULL_NAME_SERVICE_GROUP_LIST"
}

get_list_of_blades_where_vms_must_be_undefined() {
    SHORT_NAME_SERVICE_GROUP_LIST="$1"
    SERVICE_GROUP_REGEX=$(get_service_group_regex "$SHORT_NAME_SERVICE_GROUP_LIST")
    BLADES=$(/opt/ericsson/enminst/bin/vcs.bsh --groups | egrep "$SERVICE_GROUP_REGEX" | awk '{print $3}' | sort | uniq)
    echo "$BLADES"
}

offline_service_groups() {
    FULL_NAME_SERVICE_GROUP_LIST="$1"
    for SERVICE_GROUP in $FULL_NAME_SERVICE_GROUP_LIST
    do
        /opt/ericsson/enminst/bin/vcs.bsh -g $SERVICE_GROUP --offline
        /opt/ericsson/enminst/bin/vcs.bsh -g $SERVICE_GROUP --freeze
    done
}

get_vms_to_undefine() {
    FULL_NAME_SERVICE_GROUP_LIST="$1"
    VMS_TO_UNDEFINE=''
    for SERVICE_GROUP in $FULL_NAME_SERVICE_GROUP_LIST
    do
        VM=$(echo $SERVICE_GROUP | sed -e 's/Grp_CS_svc_cluster_\(.*\)/\1/g')
        VMS_TO_UNDEFINE="$VMS_TO_UNDEFINE $VM"
    done
    echo "$VMS_TO_UNDEFINE"
}

undefine_vms() {
    BLADE=$1
    VMS_TO_UNDEFINE="$2"
    for VM in $VMS_TO_UNDEFINE
    do
        /root/rvb/bin/ssh_to_vm_and_su_root.exp $BLADE "virsh undefine $VM"
    done
}

undefine_vms_on_blades() {
    BLADES="$1"
    FULL_NAME_SERVICE_GROUP_LIST="$2"
    VMS_TO_UNDEFINE=$(get_vms_to_undefine "$FULL_NAME_SERVICE_GROUP_LIST")
    for BLADE in $BLADES
    do
        undefine_vms $BLADE "$VMS_TO_UNDEFINE"
    done
}

online_service_groups() {
    FULL_NAME_SERVICE_GROUP_LIST="$1"
    for SERVICE_GROUP in $FULL_NAME_SERVICE_GROUP_LIST
    do
        /opt/ericsson/enminst/bin/vcs.bsh -g $SERVICE_GROUP --unfreeze
        /opt/ericsson/enminst/bin/vcs.bsh -g $SERVICE_GROUP --online
    done
}


[[ $# -eq 0 ]] && usage

while getopts ":r:g:i:" opt
do
    case $opt in
        r ) RPM_URL_LIST="$OPTARG" ;;
        g ) SHORT_NAME_SERVICE_GROUP_LIST="$OPTARG" ;;
        i ) JIRA_ID=$OPTARG ;;
        * ) echo "Invalid input ${opt}"; usage; exit 1 ;;
    esac
done

if ! backup_old_rpms_and_load_new_rpms_into_repo "$RPM_URL_LIST"
then
    exit 1
fi
FULL_NAME_SERVICE_GROUP_LIST=$(get_full_name_service_group_list "$SHORT_NAME_SERVICE_GROUP_LIST")
BLADES=$(get_list_of_blades_where_vms_must_be_undefined "$SHORT_NAME_SERVICE_GROUP_LIST")
if [ -z $FULL_NAME_SERVICE_GROUP_LIST ]
then
    exit 1
else
    offline_service_groups "$FULL_NAME_SERVICE_GROUP_LIST"
    undefine_vms_on_blades "$BLADES" "$FULL_NAME_SERVICE_GROUP_LIST"
    online_service_groups "$FULL_NAME_SERVICE_GROUP_LIST"
fi

