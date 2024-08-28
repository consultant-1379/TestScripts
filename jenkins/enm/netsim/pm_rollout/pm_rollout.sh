#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1
NETSIM_CFG="${BASEDIR}/netsim_cfg"
TEMPLATES_DIRS="${BASEDIR}/templates/*"
EUTRANCELL_LIST_SCRIPT="${BASEDIR}/create_eutrancell_list.sh"

. ${BASEDIR}/../../functions

install_ERICnetsim_pmcpp() {
	echo "Installing ERICnetsim_pmcpp to $NETSIMS"
    PACKAGE_NAME="ERICnetsimpmcpp_CXP9029065"
    RPM_URL="https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/content/repositories/releases/com/ericsson/cifwk/netsim/$PACKAGE_NAME"
    latest_version=`curl $RPM_URL/maven-metadata.xml | grep release | sed -e 's?.*<release>\(.*\)</release>?\1?'`
    wget $RPM_URL/${latest_version}/$PACKAGE_NAME-${latest_version}.rpm
    scp_to_hosts "$NETSIMS" root "$PACKAGE_NAME-${latest_version}.rpm" "/netsim/"
    execute_on_hosts "$NETSIMS" root "zypper install -y /netsim/$PACKAGE_NAME-${latest_version}.rpm"
}

copy_netsim_cfg() {
    execute_on_hosts "$NETSIMS" root 'rm -f /netsim/netsim_cfg'
    scp_to_hosts "$NETSIMS" netsim $NETSIM_CFG "/netsim/netsim_cfg"
}

copy_templates() {
    execute_on_hosts "$NETSIMS" root 'chown -R netsim:netsim /netsim_users/pms'
    scp_to_hosts "$NETSIMS" netsim "$TEMPLATES_DIRS" "/netsim_users/pms/"
}

copy_eutrancell_list_script () {
    scp_to_hosts "$NETSIMS" netsim "$EUTRANCELL_LIST_SCRIPT" "/netsim_users/pms/bin/create_eutrancell_list.sh"

    WRAN_CELL_LIST_FILE="/netsim_users/pms/etc/utrancell_list.txt"

    execute_on_hosts "$NETSIMS" netsim "touch $WRAN_CELL_LIST_FILE "
}

get_netsims $CLUSTERID
copy_ssh_keys_to_netsims $NETSIMS
install_ERICnetsim_pmcpp
copy_netsim_cfg
copy_templates
copy_eutrancell_list_script
write_properties_files_for_child_builds
