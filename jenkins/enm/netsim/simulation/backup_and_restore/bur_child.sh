#!/bin/bash

BASEDIR=`dirname $0`
NETSIM=$1
ACTION=$2

. ${BASEDIR}/../../netsim_backup_and_restore_functions

case "$ACTION" in
    "Backup_Simulations_Now" ) backup_simulations $NETSIM 'latest' ;;
    "Restore_Backup_Taken_At_Rollout" ) restore_simulations $NETSIM 'rollout' ;;
    "Restore_Latest_Backup" ) restore_simulations $NETSIM 'latest' ;;
esac
