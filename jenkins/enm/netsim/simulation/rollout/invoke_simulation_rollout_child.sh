#!/bin/bash -x

BASEDIR=`dirname $0`
NETSIM=$1
SIMULATED_NETWORK=$2
NETSIM_VM_NUMBER=$3
EVERY_Xth_SIMULATION_IPv6=$4

. ${BASEDIR}/../../../functions
. ${BASEDIR}/netsim_simulation_rollout_functions

stop_simulations() {
    execute_on_netsim_pipe $NETSIM '.server stop all force'
}

delete_all_db_and_filestores() {
    execute_for_each_simulation $NETSIM '.deletealldbandfs'
    execute_on_hosts $NETSIM root "mount | grep pms_tmpfs | cut -d' ' -f1 | xargs umount"
}

kill_existing_netsim_uis() {
    execute_on_hosts $NETSIM netsim "/netsim/inst/restart_gui; pkill -f netsim_shellnode; pkill -f netsim_pipenode"
}

delete_existing_simulations() {
    echo "Invokation script: Delete existing simulations on $NETSIM"
    execute_on_netsim_pipe $NETSIM '.show simulations\n.deletesimulation all_registered_simulations force\n.show simulations'
    execute_on_hosts $NETSIM netsim 'rm -f /netsim/netsimdir/*.zip; rm -rf /netsim/netsimdir/*-*'
}

remove_old_configuration() {
    execute_on_netsim_pipe $NETSIM ".reset serverloadconfig"
}

_get_simulation_names_for_this_vm_from_nw_layout_file() {
    SIMULATED_NETWORK=$1
    NETSIM_VM_NUMBER=$2
    get_nw_layout_file $SIMULATED_NETWORK >> /dev/null
    echo $(cat *nw_layout* | awk -F, "\$2==\"$NETSIM_VM_NUMBER\" {print \$1}" | sed 's/.zip//g')
}

_get_urls_for_sims_for_this_vm() {
    SIMULATED_NETWORK=$1
    NETSIM_VM_NUMBER=$2
    SIMULATION_NAMES=$(_get_simulation_names_for_this_vm_from_nw_layout_file $SIMULATED_NETWORK $NETSIM_VM_NUMBER)
    for SIMULATION_NAME in $SIMULATION_NAMES
    do
        egrep "${SIMULATION_NAME}-.*\.zip" nexus_local_urls >> urls_for_sims_for_this_vm
    done
}

get_simulations_onto_netsim() {
    SIMULATED_NETWORK=$1
    NETSIM_VM_NUMBER=$2
    NETSIM=$3
    _get_urls_for_sims_for_this_vm $SIMULATED_NETWORK $NETSIM_VM_NUMBER
    scp_to_hosts $NETSIM netsim "urls_for_sims_for_this_vm" "/netsim"
    execute_on_hosts $NETSIM netsim 'cd /netsim/netsimdir;
                                     wget --progress=dot:giga -i /netsim/urls_for_sims_for_this_vm;
                                     for file in *.zip; 
                                     do mv $file ${file%-*}.zip; 
                                     done'
    rm urls_for_sims_for_this_vm
}

uncompress_simulations() {
    echo "Invokation script: Uncompress simulations on $NETSIM"
    execute_on_hosts $NETSIM netsim "/netsim/uncompressSimulations.sh"
}

_get_simulation_specific_configuration() {
    SIMULATION=$1
    CONFIGURATION_PARAMETER=$2

    case "$CONFIGURATION_PARAMETER" in
        "node_type" ) FIELD_NUMBER=1;;
        "simulation_regex" ) FIELD_NUMBER=2;;
        "ipv6_supported" ) FIELD_NUMBER=3;;
        "snmp_args_for_autoconfig" ) FIELD_NUMBER=4;;
    esac

    cat ${BASEDIR}/node_type_specific_configuration.csv |
    while read line
    do
        SIMULATION_REGEX=$(echo $line | cut -d, -f2)
        if echo "$SIMULATION" | egrep -q "$SIMULATION_REGEX"
        then
            CONFIGURATION_VALUE=$(echo $line | cut -d, -f$FIELD_NUMBER)
            echo "$CONFIGURATION_VALUE"
            break
        fi
    done
}

_is_ipv6_supported_for_this_simulation() {
    SIMULATION=$1
    if [ "$(_get_simulation_specific_configuration $SIMULATION 'ipv6_supported')" = "true" ]
    then
        return 0
    else
        return 1
    fi
}

_get_position_number_of_simulation_in_nw_layout_file() {
    SIMULATION=$1
    SIMULATION_REGEX=$(_get_simulation_specific_configuration $SIMULATION "simulation_regex")
    SIMULATION_NUMBER=$(egrep $SIMULATION_REGEX *nw_layout* | egrep -n "${SIMULATION}\.zip" | cut -d: -f1)
    echo $SIMULATION_NUMBER
}

_is_this_the_xth_simulation_of_this_type_in_the_nw_layout_file() {
    SIMULATION=$1
    if [ $EVERY_Xth_SIMULATION_IPv6 -eq 0 ]
    then
        return 1
    fi
    SIMULATION_NUMBER=$(_get_position_number_of_simulation_in_nw_layout_file $SIMULATION)
    if [ $(($SIMULATION_NUMBER % $EVERY_Xth_SIMULATION_IPv6)) -eq 1 ]
    then
        return 0
    else
        return 1
    fi
}

_get_ip_version_for_simulation() {
    SIMULATION=$1
    if _is_ipv6_supported_for_this_simulation $SIMULATION && _is_this_the_xth_simulation_of_this_type_in_the_nw_layout_file $SIMULATION
    then
        IP_VERSION="ipv6"
    else
        IP_VERSION="ipv4"
    fi
    echo "$IP_VERSION"
}

_autoconfigure_simulation() {
    SIMULATION=$1
    IP_VERSION=$(_get_ip_version_for_simulation $SIMULATION)
    if [ "$IP_VERSION" = "ipv6" ]
    then
        OSS_ADDRESS='0:0:0:0:0:0:0:1'
    else
        OSS_ADDRESS='127.0.0.1'
    fi
    SNMP_ARGUMENTS_FOR_AUTOCONFIG=$(_get_simulation_specific_configuration $SIMULATION "snmp_args_for_autoconfig")
    execute_on_netsim_pipe $NETSIM ".autoconfig -simulations $SIMULATION -oss_address $OSS_ADDRESS -base_address $IP_VERSION -force_new_ports -force_new_externals $SNMP_ARGUMENTS_FOR_AUTOCONFIG"
}

_get_load_balancing_value_for_simulation() {
    SIMULATION=$1
    echo $(cat *nw_layout* | egrep "${SIMULATION}\.zip" | cut -d, -f3)
}

_get_node_type_version_of_simulation() {
    SIMULATION=$1
    NODE_TYPE_VERSION=$(execute_on_netsim_pipe $NETSIM ".open $SIMULATION\n.show simnes" | grep netsim | tail -1 | awk '{print $3" "$4}')
    echo $NODE_TYPE_VERSION
}

_apply_load_balancing_on_simulation() {
    SIMULATION=$1
    LOAD_BALANCING_VALUE=$(_get_load_balancing_value_for_simulation $SIMULATION)
    NODE_TYPE_VERSION=$(_get_node_type_version_of_simulation $SIMULATION)
    execute_on_netsim_pipe $NETSIM ".set nodeserverload $NODE_TYPE_VERSION $LOAD_BALANCING_VALUE\n.show serverloadconfig" 
}

_toggle_yang_to_static(){
    SIMULATION=$1
    execute_on_netsim_pipe $NETSIM ".toggleyangto static"
}

configure_simulations() {
    for SIMULATION in $SIMULATION_NAMES
    do
        _autoconfigure_simulation $SIMULATION
        _apply_load_balancing_on_simulation $SIMULATION
        _toggle_yang_to_static $SIMULATION
    done
}

save_config() {
    execute_on_netsim_pipe $NETSIM ".select configuration\n.config save\n.config export conf_at_rollout force"
}

start_simulations() {
    execute_on_hosts $NETSIM netsim "/netsim/startStop.sh start"
}


#MAIN
copy_ssh_keys_to_netsims $NETSIM
stop_simulations
delete_all_db_and_filestores
kill_existing_netsim_uis
delete_existing_simulations
remove_old_configuration
if [ $NETSIM_VM_NUMBER -gt 0 ]
then
    get_simulations_onto_netsim $SIMULATED_NETWORK $NETSIM_VM_NUMBER $NETSIM
    uncompress_simulations
    configure_simulations
    save_config
    start_simulations
fi
