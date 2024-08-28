#!/bin/bash -x

BASEDIR=`dirname $0`
CLUSTERID=$1
SIMULATED_NETWORK=$2

. ${BASEDIR}/../../../functions
. ${BASEDIR}/netsim_simulation_rollout_functions

check_that_deployment_has_enough_netsims_for_simulated_network() {
    get_nw_layout_file $SIMULATED_NETWORK
    REQUIRED_NUMBER_OF_NETSIMS=$(($(cat *nw_layout* | cut -d, -f2 | sort | uniq | wc -l)-1))
    AVAILABLE_NETSIMS=($NETSIMS)
    NUMBER_OF_AVAILABLE_NETSIMS=${#AVAILABLE_NETSIMS[*]}
    if [ $REQUIRED_NUMBER_OF_NETSIMS -gt $NUMBER_OF_AVAILABLE_NETSIMS ]
    then
        echo "$SIMULATED_NETWORK requires $REQUIRED_NUMBER_OF_NETSIMS netsim VMs but there are only $NUMBER_OF_AVAILABLE_NETSIMS in this deployment"
        exit 1
    fi
}

copy_rollout_scripts_to_netsims() {
    echo "Invokation script: Copying rollout scripts to: $NETSIMS"
	scp_to_hosts "$NETSIMS" netsim "${BASEDIR}/netsim/*" "/netsim"
}

write_properties_file_for_simulation_child_build() {
    i=1
    for NETSIM in $NETSIMS
    do
        if [ $i -gt $REQUIRED_NUMBER_OF_NETSIMS ]
        then
            NETSIM_VM_NUMBER=0
        else
            NETSIM_VM_NUMBER=$i
        fi
        PROPERTIES_FILE="${BASEDIR}/../../../${NETSIM}_child.prop"
        echo "NETSIM=$NETSIM" >> $PROPERTIES_FILE
        echo "NETSIM_VM_NUMBER=$NETSIM_VM_NUMBER" >> $PROPERTIES_FILE
        echo "EVERY_Xth_SIMULATION_IPv6=$EVERY_Xth_SIMULATION_IPv6" >> $PROPERTIES_FILE
        i=$(($i+1))
    done
}


#MAIN
get_deployment_conf $CLUSTERID
get_netsims
check_that_deployment_has_enough_netsims_for_simulated_network
copy_ssh_keys_to_netsims $NETSIMS
copy_rollout_scripts_to_netsims
write_properties_file_for_simulation_child_build
