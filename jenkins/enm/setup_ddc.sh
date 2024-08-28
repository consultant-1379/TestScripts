#!/bin/bash

BASENAME=`dirname $0`
CLUSTERID=$1

. ${BASENAME}/functions

mount_ddp_to_lms(){
    echo "$FUNCNAME - $(date)"
    mkdir -p /net/ddpi/data/stats;
    [[ -z $(mount | egrep ddpi:) ]] && mount ddpi:/data/stats /net/ddpi/data/stats || echo "already mounted"
    mkdir -p /net/ddp/data/stats;
    [[ -z $(mount | egrep ddp:) ]] && mount ddp:/data/stats /net/ddp/data/stats || echo "already mounted"
    mkdir -p /net/ddpenm2/data/stats;
    [[ -z $(mount | egrep ddpenm2:) ]] && mount ddpenm2:/data/stats /net/ddpenm2/data/stats || echo "already mounted"

}

setup_lms_ddc_upload() {
    echo "$FUNCNAME - $(date)"
    mkdir -p /etc/cron.d
    echo "30 0-22 * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM$CLUSTERID -d ddpenm2" > /etc/cron.d/ddc_upload
    echo "10 23 * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM$CLUSTERID -d ddpenm2" >> /etc/cron.d/ddc_upload
    chmod 0644 /etc/cron.d/ddc_upload
}

collect_ddc_from_remote_hosts(){
    echo "$FUNCNAME - $(date)"
    touch /var/ericsson/ddc_data/config/server.txt
    for NETSIM in $NETSIMS
    do
        echo "$NETSIM=NETSIM" >> /var/ericsson/ddc_data/config/server.txt
    done
}

setup_ddc_sfs_clariion() {
    touch /var/ericsson/ddc_data/config/MONITOR_SFS
    touch /var/ericsson/ddc_data/config/MONITOR_CLARIION
}

main(){
    mount_ddp_to_lms
    collect_ddc_from_remote_hosts
    setup_ddc_sfs_clariion
    setup_lms_ddc_upload
}

if [[ -z $1 ]];
then
    echo "No cluster ID passed in, exiting..."
    exit 1
fi

main