#!/bin/bash

BASENAME=`dirname $0`
CLUSTERID=$1

. ${BASENAME}/../functions


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

install_available_licenses() {
    echo "$FUNCNAME - $(date)"
    cd ${BASENAME}/../licenses
	for LICENSE in *
    do
        /opt/ericsson/enmutils/bin/cli_app "lcmadm install file:$LICENSE" $LICENSE
    done
    cd -
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

            echo "Copying /root/rvb/copy-rsa-key-to-remote-host.exp to WORKLOAD_SERVER"
            scp /root/rvb/copy-rsa-key-to-remote-host.exp $WORKLOAD_SERVER:/var/tmp

        echo "Set up passwordless ssh access from WORKLOAD SERVER to LMS"
        ERROR_MSG="The expect executable, i.e /usr/bin/expect, is missing - cannot setup passwordless ssh access from WORKLOAD SERVER to LMS"
            ssh $WORKLOAD_SERVER "[[ -r /usr/bin/expect ]] && echo \$(/var/tmp/copy-rsa-key-to-remote-host.exp $LMS_HOSTNAME root 12shroot) || echo $ERROR_MSG "

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

set -x

[[ -z $CLUSTERID ]] && { echo "Need to provide CLUSTERID...exiting."; exit 1; }

get_deployment_conf $CLUSTERID
get_netsims
install_internal_torutils
install_available_licenses
copy_ssh_keys_to_netsims $NETSIMS
generate_tls_dg2_cert
setup_workload_vm
echo "Script complete - $(date)"
