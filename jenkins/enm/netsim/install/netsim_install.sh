#!/bin/bash

BASEDIR=`dirname $0`
NETSIM=$1
NETSIM_VERSION=$2
TEMP_INSTALL_DIR_ON_NETSIM="/netsim/${NETSIM_VERSION}"


. ${BASEDIR}/../../functions


install_netsim_and_patches() {
    execute_on_hosts $NETSIM netsim "/netsim/inst/stop_netsim"
    execute_on_hosts $NETSIM root "cd $TEMP_INSTALL_DIR_ON_NETSIM; ls | egrep -v '.sh|.zip' | xargs rm; sh Unbundle.sh"
}

make_netsim_64bit() {
    execute_on_hosts $NETSIM netsim "/netsim/inst/stop_netsim; sed -i -e 's/NETSIM_ENABLE_64BIT_SUPPORT:-false/NETSIM_ENABLE_64BIT_SUPPORT:-true/' /netsim/inst/architectures.sh; /netsim/inst/start_netsim_64"
}

start_nodes() {
    execute_for_each_simulation $NETSIM ".select network\n.start"
}

create_init() {
    execute_on_hosts $NETSIM root "/netsim/inst/bin/create_init.sh -a"
}

show_patches_on_netsim() {
    execute_on_netsim_pipe $NETSIM '.show installation\n.show patch info'
}

copy_ssh_keys_to_netsims $NETSIM
install_netsim_and_patches
make_netsim_64bit
start_nodes
create_init
show_patches_on_netsim
