#!/bin/bash

BASENAME=`dirname $0`
NETSIM=$1

. ${BASENAME}/../functions

setup_tls_dg2() {
    execute_on_hosts $NETSIM netsim "/netsim/inst/tlsport.sh | /netsim/inst/netsim_pipe"
}

sync_netsim_time(){
    execute_on_hosts $NETSIM root '/usr/sbin/rcntp ntptimeset'
}

copy_ssh_keys_to_netsims $NETSIM
setup_tls_dg2
sync_netsim_time
