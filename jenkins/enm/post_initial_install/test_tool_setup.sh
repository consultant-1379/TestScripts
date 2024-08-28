#!/bin/bash

setup_pmic_volume_info_collection() {
    # Setup cron to take listing of PM files and symlinks to assist with troubleshooting collection problems
    echo "30 6 * * * root /root/rvb/bin/get_pmic_volume_file_listing.sh > /dev/null 2>&1" > /etc/cron.d/collect_pm_info
}

get_node_ip_addresses() {
    echo "$FUNCNAME - $(date)"
    # Get IP addresses of Nodes
    /opt/ericsson/enmutils/bin/cli_app 'cmedit get * CppConnectivityInformation.ipAddress' | egrep '^FDN|^ip' | paste - - > /ericsson/enm/dumps/nodes.cpp.ipaddress
    /opt/ericsson/enmutils/bin/cli_app 'cmedit get * ComConnectivityInformation.ipAddress' | egrep '^FDN|^ip' | paste - - > /ericsson/enm/dumps/nodes.com.ipaddress
}

cm_stkpi_tests_setup() {
    echo "$FUNCNAME - $(date)"
        OFFSET=$1
        AT_SCRIPT="~/.CMCLI_STKPI_TESTS_SETUP_SCRIPT"
        DUMPS_DIR="/ericsson/enm/dumps"
    CMD_GET_EUTRANCELLS="/opt/ericsson/enmutils/bin/cli_app 'cmedit get \* EUtranCellFDD'"
    EUTRANCELL_LIST_FILE="$DUMPS_DIR/EUtranCellFDD.list"


        # Schedule CM_CLI to run twice per hour
        #Lock 100 random cells on Netsim
        echo "6,36 * * * * root [[ -f /ericsson/enm/dumps/.stkpi_CMCLI_01.ok_to_run ]] && /root/rvb/bin/stkpi_CMCLI_01.sh -n -l 100 -f $DUMPS_DIR/EUtranCellFDD.list > /dev/null" > /etc/cron.d/stkpi_CMCLI_01
        #Unlock all locked cells
        echo "21,51 * * * * root [[ -f /ericsson/enm/dumps/.stkpi_CMCLI_01.ok_to_run ]] && /root/rvb/bin/stkpi_CMCLI_01.sh -n -u  > /dev/null" >>  /etc/cron.d/stkpi_CMCLI_01


        # Schedule CM_Change_01 to run twice per hour
        echo "13,43 * * * * root [[ -f /ericsson/enm/dumps/.stkpi_CM_Change_01.ok_to_run ]] && /root/rvb/bin/stkpi_CM_Change_01.sh -n -u ENodeBFunction  > /dev/null" > /etc/cron.d/stkpi_CM_Change_01



        #TODO: unlock all cells in network - supposed to be delivered by default with 16.8 sims
    echo "$FUNCNAME: Scheduling the following to occur $OFFSET mins from now"
    echo "1: unlock all cells in network - supposed to be delivered by default with 16.8 sims"
        echo "/root/rvb/bin/stkpi_CMCLI_01.sh -n -p "          > $AT_SCRIPT
        echo "/root/rvb/bin/stkpi_CMCLI_01.sh -s "            >> $AT_SCRIPT
    echo "sleep 10"                                       >> $AT_SCRIPT

    echo "2: get list of all cells for CMCLI_01"
    echo "$CMD_GET_EUTRANCELLS > $EUTRANCELL_LIST_FILE"   >> $AT_SCRIPT

    if [ "$ENABLE_STKPI_TESTS" == "TRUE" ]; then
        echo "3: Enable the 2 STKPI CM CLI cron scripts to run"
        echo "touch $DUMPS_DIR/.stkpi_CM_Change_01.ok_to_run" >> $AT_SCRIPT
        echo "touch $DUMPS_DIR/.stkpi_CMCLI_01.ok_to_run"     >> $AT_SCRIPT
    fi

    # Schedule the above commands to run
        at -f $AT_SCRIPT now + $OFFSET minutes

}

setup_pmic_volume_info_collection
get_node_ip_addresses
cm_stkpi_tests_setup 270
#set up CM_Synch_01
echo "# 0,30 1-8 * * * root /root/rvb/bin/stkpi_CM_Synch_01.bsh" > /etc/cron.d/stkpi_CM_Synch_01
echo "# 0 1 * * * root /root/rvb/bin/ERBS_Network_Sync.bsh" >> /etc/cron.d/stkpi_CM_Synch_01

echo
echo "List of scheduled at jobs"
for JOB in $(atq | awk '{print $1}' | sort); do echo $(atq | egrep -w $JOB); at -c $JOB | perl -ne 'print if /marc/../^marc/' | egrep -v 'marc|^$'; echo; done
echo
