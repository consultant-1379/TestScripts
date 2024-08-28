#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1

. ${BASEDIR}/../../functions


get_netsim_license() {
    wget http://netsim.lmera.ericsson.se/licences/Generic_Ericsson.415.4.netsim6_8_licence.zip
}

copy_license_to_netsims() {
    scp_to_hosts "$NETSIMS" netsim "Generic_Ericsson.415.4.netsim6_8_licence.zip" "/netsim/inst"
}

install_license() {
	execute_on_netsim_pipe "$NETSIMS" '.install license Generic_Ericsson.415.4.netsim6_8_licence.zip'
	execute_on_netsim_pipe "$NETSIMS" '.show license'
}

get_netsims $CLUSTERID
copy_ssh_keys_to_netsims $NETSIMS
get_netsim_license
copy_license_to_netsims
install_license
