#!/bin/bash

BASEDIR=`dirname $0`
NETSIM=$1
SCANNERS_SCRIPT="${BASEDIR}/scanners.sh"
NETSIM_CRON_ENTRIES=`cat ${BASEDIR}/netsim_crontab`
ROOT_CRON_ENTRIES=`cat ${BASEDIR}/root_crontab`

. ${BASEDIR}/../../functions


create_set_tmpfs() {
    if echo $NETSIM | grep -q 'v'
    then
        SIZE='20G'
    else
        SIZE='32G'
    fi
    execute_on_hosts "$NETSIM" root "cp /etc/fstab /etc/fstab.sav; cat /etc/fstab.sav | grep -v pms_tmpfs > /etc/fstab; echo 'tmpfs /pms_tmpfs tmpfs rw,size=$SIZE 0 0' >> /etc/fstab; mkdir -p /pms_tmpfs; mount -a; chown netsim:netsim /pms_tmpfs"
	execute_on_hosts $NETSIM netsim '/netsim_users/pms/bin/settmpfs.sh'
}

apply_bandwidth_limiting() {
    execute_on_hosts $NETSIM root '/netsim_users/pms/bin/limitbw -n -c'
}

remove_old_files() {
    execute_on_hosts $NETSIM netsim 'rm /tmp/showstartednodes.txt; rm /tmp/nodetypes.txt'
}

create_dummy_files_dynamically() {
    execute_on_hosts $NETSIM netsim 'dd if=/dev/zero of=/netsim_users/pms/rec_templates/mme_ctum bs=1024 count=10240; dd if=/dev/zero of=/netsim_users/pms/rec_templates/mme_uetrace bs=1024 count=1024'
    execute_on_hosts $NETSIM netsim 'rm /netsim_users/pms/rec_templates/ebs_*; for i in {1..3}; do dd if=/dev/zero of=/netsim_users/pms/rec_templates/ebs_$i bs=1024 count=10240; done; dd if=/dev/zero of=/netsim_users/pms/rec_templates/ebs_4 bs=1024 count=9216'
    #execute_on_hosts $NETSIM netsim 'for i in 750 2250; do cat /dev/random | dd iflag=fullblock bs=1024 count=$i | gzip > /netsim_users/pms/rec_templates/celltrace_${i}k.bin.gz; done'
    execute_on_hosts $NETSIM netsim 'for i in 1000 3000; do cat /dev/random | dd iflag=fullblock bs=1024 count=$i | gzip > /netsim_users/pms/rec_templates/celltrace_${i}k.bin.gz; done'
}

create_eutrancell_list() {
    execute_on_hosts $NETSIM netsim '/netsim_users/pms/bin/create_eutrancell_list.sh refresh'
}

populate_crontab() {
    execute_on_hosts $NETSIM netsim "echo \"$NETSIM_CRON_ENTRIES\" | crontab - "
    execute_on_hosts $NETSIM root "crontab -l | egrep -v '^# |limitbw' > /tmp/new_crontab; echo \"$ROOT_CRON_ENTRIES\" > /tmp/new_crontab; crontab /tmp/new_crontab"
}

create_scanners() {
    scp_to_hosts $NETSIM netsim $SCANNERS_SCRIPT "/netsim_users/pms/bin/scanners.sh"
	execute_on_hosts $NETSIM netsim '/netsim_users/pms/bin/scanners.sh -a create'
}

copy_ssh_keys_to_netsims $NETSIM
create_set_tmpfs
apply_bandwidth_limiting
remove_old_files
create_dummy_files_dynamically
create_eutrancell_list
populate_crontab
create_scanners
