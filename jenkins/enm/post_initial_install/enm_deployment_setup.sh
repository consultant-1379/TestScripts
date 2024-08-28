#!/bin/bash

BASENAME=`dirname $0`
CLUSTERID=$1

. ${BASENAME}/../functions

setup_passwordless_access() {
    echo "$FUNCNAME - $(date)"
    cd /root/rvb/ssh_keys
    for file in *
    do
        cat $file >> /root/.ssh/authorized_keys
    done
    cd -
}

setup_lms_ddc_upload() {
    echo "$FUNCNAME - $(date)"
    mkdir -p /etc/cron.d
    echo "30 0-22 * * * root /opt/ericsson/ERICddc/bin/ddcDataUpload -s ENM$CLUSTERID -d $DDP_SERVER" > /etc/cron.d/ddc_upload
    echo "10 23 * * * root /opt/ericsson/ERICddc/bin/ddcDataUpload -s ENM$CLUSTERID -d $DDP_SERVER" >> /etc/cron.d/ddc_upload
    chmod 0644 /etc/cron.d/ddc_upload
}

setup_server_status_cron() {
    echo "$FUNCNAME - $(date)"
    if [ "${SERVER_STATUS_ENABLED}" == "true" ]; then
        mkdir -p /etc/cron.d
        echo "20 4 * * * root /root/rvb/bin/checkServerStatusS4.pl" > /etc/cron.d/server_status
        echo "50 4 * * * root /root/rvb/bin/mailServerStatusS4.sh $CLUSTERID" >> /etc/cron.d/server_status
        chmod 0644 /etc/cron.d/server_status
    fi
}

setup_ddc_sfs_clariion() {
    echo "$FUNCNAME - $(date)"
    touch /var/ericsson/ddc_data/config/MONITOR_SFS
    touch /var/ericsson/ddc_data/config/MONITOR_CLARIION
}

setup_ddc_nonlive_mo(){
    echo "$FUNCNAME - $(date)"
    touch /var/ericsson/ddc_data/config/MONITOR_DPS_NONLIVE
}

setup_ddc_fls(){
    echo "$FUNCNAME - $(date)"
    touch /var/ericsson/ddc_data/config/MONITOR_FLS
}
setup_ddc_vc(){
    echo "$FUNCNAME - $(date)"
    SED=/software/autoDeploy/MASTER_siteEngineering.txt
    MONITOR_VC=/var/ericsson/ddc_data/config/MONITOR_VC

    if [ -f ${SED} ]; then

        echo "Setting up Virtual Connect info. for DDC upload"
        /bin/touch ${MONITOR_VC}
        /bin/egrep VC_IP. ${SED} |awk -F = '{print $2}' | awk '{print}' ORS=',' | sed '$s/.$//' > ${MONITOR_VC}
        yum install -y net-snmp-utils
        service ddc restart
    else
        echo "Expected SED file $SED does not exist!!"
    fi
}
fetch_enmutils_rpm_from_nexus() {
    echo "$FUNCNAME - $(date)"
    nexus='https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus'; 
    gr='com.ericsson.dms.torutility'; 
    art='ERICtorutilitiesinternal_CXP9030579'; 
    ver=`/usr/bin/repoquery -a --repoid=ms_repo --qf "%{version}" ERICtorutilities_CXP9030570`; 
    wget -O $art-$ver.rpm "$nexus/service/local/artifact/maven/redirect?r=releases&g=${gr}&a=${art}&v=${ver}&e=rpm"
}


install_internal_torutils() {
    echo "$FUNCNAME - $(date)"
    if [ -e /opt/ericsson/enmutils/.deploy/update_enmutils_rpm ]; then
        echo "torutils_internal is already installed"
    else
        # Install the iso version of utilities
	fetch_enmutils_rpm_from_nexus
        yum install -y $art-$ver.rpm
    fi
    if [ -z $TORUTILS_VERSION ]; then
        ver=`/usr/bin/repoquery -a --repoid=ms_repo --qf "%{version}" ERICtorutilities_CXP9030570`
    else
        ver=$TORUTILS_VERSION
    fi
    /opt/ericsson/enmutils/.deploy/update_enmutils_rpm $ver

    if [ ! -z $WORKLOAD_SERVER ]; then
        TORUTILS_VERSION_ON_LMS=$(/opt/ericsson/enmutils/.deploy/update_enmutils_rpm -s | grep installed | awk '{print $3}')
        /root/rvb/copy-rsa-key-to-remote-host.exp $WORKLOAD_SERVER root 12shroot
	echo "Checking if enmutils already installed on WORKLOAD_SERVER"
	ENMUTILS_INSTALLED=$(ssh $WORKLOAD_SERVER "[[ -e /opt/ericsson/enmutils/.deploy/update_enmutils_rpm ]] && echo YES || echo NO")
	if [ "$ENMUTILS_INSTALLED" == "NO" ]
	then
		fetch_enmutils_rpm_from_nexus
		scp $art-$ver.rpm $WORKLOAD_SERVER:/var/tmp
		ssh $WORKLOAD_SERVER "yum install -y /var/tmp/$art-$ver.rpm"
	else
	    ENMUTILS_VERSION_INSTALLED=$(ssh $WORKLOAD_SERVER 'rpm -q ERICtorutilitiesinternal_CXP9030579 | sed "s/-[^-]*$//" | sed "s/^.*-//g"')
	    if [ "$ENMUTILS_VERSION_INSTALLED" == "$TORUTILS_VERSION_ON_LMS" ]
	    then
	        echo "Version installed on WORKLOAD_SERVER: $ENMUTILS_VERSION_INSTALLED matches version currently installed on LMS: $TORUTILS_VERSION_ON_LMS - no update required"
	    else
	        echo "Version installed on WORKLOAD_SERVER: $ENMUTILS_VERSION_INSTALLED doesnt match version currently installed on LMS: $TORUTILS_VERSION_ON_LMS - update required"
            ssh $WORKLOAD_SERVER "/opt/ericsson/enmutils/.deploy/update_enmutils_rpm $TORUTILS_VERSION_ON_LMS"
        fi
	fi

    fi
}

collect_ddc_from_remote_hosts() {
    echo "$FUNCNAME - $(date)"
    touch /var/ericsson/ddc_data/config/server.txt
    for NETSIM in $NETSIMS
    do
        echo "$NETSIM=NETSIM" >> /var/ericsson/ddc_data/config/server.txt
    done
}

install_available_licenses() {
    echo "$FUNCNAME - $(date)"
    cd ${BASENAME}/../licenses
	for LICENSE in *
    do
        /opt/ericsson/enmutils/bin/cli_app "lcmadm install file:$LICENSE" $LICENSE
    done
    cd -
}

mount_ddp_to_lms() {
    echo "$FUNCNAME - $(date)"
    mkdir -p /net/ddpi/data/stats; 
    [[ -z $(mount | egrep ddpi:) ]] && mount ddpi:/data/stats /net/ddpi/data/stats || echo "already mounted"
    mkdir -p /net/ddp/data/stats; 
    [[ -z $(mount | egrep ddp:) ]] && mount ddp:/data/stats /net/ddp/data/stats || echo "already mounted"
    mkdir -p /net/$DDP_SERVER/data/stats;
    [[ -z $(mount | egrep $DDP_SERVER:) ]] && mount $DDP_SERVER:/data/stats /net/$DDP_SERVER/data/stats || echo "already mounted"
}

install_guestfish_on_blades() {
    echo "$FUNCNAME - $(date)"
     echo "# Install guestfish on blades"
     for NODE in $(litp show -p /deployments/enm/clusters/svc_cluster/nodes | egrep -v ':|deploy.*svc_cluster' | awk -F'/' '{print $2}')
     do
         echo "# Enable password-less ssh access to $NODE for litp-admin user"
         /root/rvb/copy-rsa-key-to-remote-host.exp $NODE litp-admin

         echo "# Install Guestfish on $NODE"
         /root/rvb/guestfish_installer.exp $NODE
     done
}

copy_files_to_dumps_dir() {
    echo "$FUNCNAME - $(date)"
    REPODIR=${BASENAME}/../dumps_dir
    DUMPSDIR=/ericsson/enm/dumps/.scripts
    /bin/mkdir -p ${DUMPSDIR}
    # Copy everything from the dumps_dir in repo to dumps on MS
    FILES=`ls ${REPODIR}`
    for FILE in ${FILES}
    do
        /bin/cp $REPODIR/${FILE} ${DUMPSDIR}
    done
}

create_testers_group() {
    echo "$FUNCNAME - $(date)"
    groupadd -f testers
    groupadd -f privileged_testers
    groupadd -f endurance_testers
    /bin/cp -f /root/rvb/post_initial_install/teaas_sudoers_file /etc/sudoers.d/teaas
    /bin/cp -f /root/rvb/post_initial_install/endurance_sudoers_file /etc/sudoers.d/endurance
}

setup_passwordless_ssh_from_jiralistener() {
    echo "$FUNCNAME - $(date)"
    JL_SERVER="atvts2503.athtem.eei.ericsson.se"
    LMS_HOSTNAME=$(hostname)
    echo "Setting up passwordless SSH from JiraListener"
    /root/rvb/copy-rsa-key-to-remote-host.exp $JL_SERVER root shroot
    scp /root/rvb/copy-rsa-key-to-remote-host.exp $JL_SERVER:/var/tmp
    ssh $JL_SERVER "/var/tmp/copy-rsa-key-to-remote-host.exp $LMS_HOSTNAME root 12shroot"
}

restrict_root_ssh_with_password() {
    echo "$FUNCNAME - $(date)"
    if [ ! -z "$PERMIT_ROOT_LOGIN" ]
    then
        sed -i "s/#PermitRootLogin yes/PermitRootLogin $PERMIT_ROOT_LOGIN/g" /etc/ssh/sshd_config
        service sshd restart
    fi
}

dont_use_strict_host_key_check_from_lms() {
    echo "$FUNCNAME - $(date)"
    sed -i "s/# Host/Host/g" /etc/ssh/ssh_config
    sed -i "s/#   StrictHostKeyChecking ask/   StrictHostKeyChecking no/g" /etc/ssh/ssh_config
}

add_call_to_jira_listener_to_sync_users_post_reboot() {
    echo "$FUNCNAME - $(date)"
    echo "curl http://atvts2503.athtem.eei.ericsson.se:8000/jiralistener/sync/$CLUSTERID/" >> /etc/rc.d/rc.local
}

generate_tls_dg2_cert() {
    echo "$FUNCNAME - $(date)"
    /opt/ericsson/enmutils/bin/cli_app "pkiadm entitymgmt --create --xmlfile file:End-Entity.xml" /root/rvb/bin/End-Entity.xml
    /opt/ericsson/enmutils/bin/cli_app "pkiadm certmgmt EECert --generate -nocsr --entityname NODE_DUSGen2OAM_ENTITY --format P12 --password secured" | strings -n 8 > /tmp/generate.log
    FILE=$(grep 'Downloaded file' /tmp/generate.log | awk '{print $NF}')
    mv ${FILE} /root/NODE_DUSGen2OAM_ENTITY.p12
    scp_to_hosts "$NETSIMS" netsim ${BASENAME}/../bin/tlsport.sh /netsim/inst/
    execute_on_hosts "$NETSIMS" root "if [ -f /netsim/NODE_DUSGen2OAM_ENTITY.p12 ]; then rm -f /netsim/NODE_DUSGen2OAM_ENTITY.p12; fi"
    scp_to_hosts "$NETSIMS" netsim /root/NODE_DUSGen2OAM_ENTITY.p12 /netsim/
}

setup_workload_vm() {
    echo "$FUNCNAME - $(date)"
    if [ ! -z $WORKLOAD_SERVER ]; then
        echo "Enable password-less access to WORKLOAD_SERVER if needed"
        /root/rvb/copy-rsa-key-to-remote-host.exp $WORKLOAD_SERVER root 12shroot

        BASHRC="/root/.bashrc"

        echo "Add alias to LMS to allow for quick connection to WORKLOAD_SERVER"
        sed -i 's/.*WORKLOAD_.*//' $BASHRC
        # BR Jenkins Jobs expect WORKLOAD_VM instead of WORKLOAD_SERVER in bashrc file
        echo "WORKLOAD_VM=$WORKLOAD_SERVER" >> $BASHRC
        echo "alias connect_to_vm='ssh -o StrictHostKeyChecking=no \$WORKLOAD_VM'" >> $BASHRC

            echo "Add WORKLOAD_SERVER to list of remotehosts that DDC will collect stats from"
            echo ${WORKLOAD_SERVER}=WORKLOAD >> /var/ericsson/ddc_data/config/server.txt

            echo "Update .bashrc file on WORKLOAD_SERVER to indicate which LMS it will be connected to"
            LMS_HOSTNAME=$(hostname)
            ssh $WORKLOAD_SERVER "sed -i 's/.*LMS_HOST.*//' $BASHRC; echo \"export LMS_HOST=$LMS_HOSTNAME\" >> $BASHRC"

        echo "Set up passwordless ssh access from WORKLOAD SERVER to LMS"
        WORKLOAD_PUBLIC_SSH_KEY=$(ssh $WORKLOAD_SERVER 'cat /root/.ssh/id_rsa.pub')
        echo $WORKLOAD_PUBLIC_SSH_KEY >> /root/.ssh/authorized_keys 

        echo "Perform hard shutdown of workload on WORKLOAD_SERVER, in case not already done"
        echo "1. Kill all profile daemon processes running on WORKLOAD_SERVER"
        ssh $WORKLOAD_SERVER 'P1=/opt/ericsson/enmutils; P2=/.env/bin/daemon; [[ ! -z $(pgrep -f "$P1$P2") ]] && { echo "Killing enmutil daemons on WL Server"; pkill -f "$P1$P2"; } || echo "No enmutils daemons running on WL Server" '

        echo "2. Remove PID files - only stored on MS"
        rm -rf /tmp/enmutils/daemon/profiles/

        echo "3. Clear all persisted objects on WORKLOAD_SERVER"
        ssh $WORKLOAD_SERVER "/opt/ericsson/enmutils/bin/persistence clear force"

    else
        echo "No WORKLOAD_SERVER variable has been defined in deployment conf file - cannot make required changes Workload Server"
    fi

}

remove_ddpi_cron(){
    echo "$FUNCNAME - $(date)"
    CRON_FILE="/var/spool/cron/root"
    [[ -f $CRON_FILE ]] &&  { echo "Removing default ddc upload cron job"; sed -i '/ddcDataUpload/d' $CRON_FILE; } || echo "Nothing to do - cron file $CRON_FILE does not exist";
}

set -x

[[ -z $CLUSTERID ]] && { echo "Need to provide CLUSTERID...exiting."; exit 1; }

get_deployment_conf $CLUSTERID
get_netsims
setup_passwordless_access
remove_ddpi_cron
setup_lms_ddc_upload
setup_server_status_cron
setup_ddc_sfs_clariion
setup_ddc_nonlive_mo
setup_ddc_vc
setup_ddc_fls
collect_ddc_from_remote_hosts
mount_ddp_to_lms
install_internal_torutils
install_available_licenses
copy_ssh_keys_to_netsims $NETSIMS
install_guestfish_on_blades
copy_files_to_dumps_dir
${BASENAME}/update_lms_bashrc.sh
create_testers_group
setup_passwordless_ssh_from_jiralistener
restrict_root_ssh_with_password
dont_use_strict_host_key_check_from_lms
add_call_to_jira_listener_to_sync_users_post_reboot
# generate_tls_dg2_cert
setup_workload_vm
echo "Script complete - $(date)"
