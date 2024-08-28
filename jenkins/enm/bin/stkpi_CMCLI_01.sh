#!/bin/bash

KPI=STKPI_CMCLI_01
TITLE="CMCLI: SET one attribute on all Cells under an MeContext in the ERBS node model"
echo ""
echo "Script to perform actions in relation to testing the ST KPI: $KPI"


_initialize_logfile() {
        OUTPUT_DIR="/ericsson/enm/dumps/KPI_LOGFILES"
        [[ ! -d $OUTPUT_DIR ]] && mkdir -p $OUTPUT_DIR

        SCRIPT=$(basename $0)
        SCRIPT_FILENAME=${SCRIPT%.*}
        TODAY_DATE=$(date +%y%m%d)
        LOGFILE=$OUTPUT_DIR/$SCRIPT_FILENAME.$TODAY_DATE.log

        # compress the older files is they exist
        OLD_LOGFILE_LIST=$(ls $OUTPUT_DIR | egrep $SCRIPT_FILENAME | egrep -v $TODAY_DATE | egrep -v '.gz$') 
        for FILE in $OLD_LOGFILE_LIST; do gzip $OUTPUT_DIR/$FILE; done
}

_displayHelpMessage() {
        echo ""
        echo "$KPI: $TITLE"
        echo "Usage: $0 [ -n ] {-s | -u | -l number_of_cells [ -f file_containing_fdn_list ] | -p } [ | -h | -d ]"
        echo ""
        echo "where"
        echo " -n        No confirmation - Dont ask user to confirm before executing cmedit write commands. Script will ask for confirmation by default"
        echo " -s        Status - Check cell lock status"
        echo " -u        Unlock all locked cells in network, i.e. Perform the actual KPI test iself"
        echo " -l        Lock random number of cells"
        echo " -f        File - Specifies the file containing the cell fdn list for whole network (use to save time rereading this info)"
        echo "               - file can be created using following command, otherwise script will create this itself: "
        echo "                   /opt/ericsson/enmutils/bin/cli_app \"cmedit get * EUtranCellFDD\" > /ericsson/enm/dumps/EUtranCellFDD.list"
        echo " -p        Prepare - This is essentially the same as '-u', i.e. setup pre-conditions "
        echo "               i.e. set all cells to be unlocked, by subnetwork (i.e. simulation) to spread out load on ENM"
        echo " -h        Help - Displays this message"
        echo " -d        Description - About the KPI"
        exit 0
}


_about() {

echo "

Title
=====
$TITLE

Description
===========
CMCLI:  
ENM CLI shall support 100 Users/sessions and scripting shall support 100 users/sessions, 
any combination of these number of users shall be supported.  

- LMIJGE: this is covered by TERE Workload Profile: CMCLI_02 and will not be addressed by this test

An ENM CLI Query/Update towards configuration data (example UNLOCK all LOCKED cells in the Network, 
where maximum of 100 Cells shall be UNLOCKED) shall not take more than 30 seconds  

Requirement: 
===========
30 seconds

"

}



_check_network_sync_status() {
        echo "Checking Node sync status"
        COMMAND="/opt/ericsson/enmutils/bin/network sync-status"
        echo "Executing $COMMAND"
        eval $COMMAND

}

_logme() {
        MESSAGE=$1
        echo $MESSAGE
        echo $MESSAGE >> $LOGFILE
}


_check_cell_status() {
        _logme "Checking the administrativeState for EUtranCellFDD's in the network"
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "cmedit get \* EUtranCellFDD.administrativeState==LOCKED --count"'
        _logme "Executing: $CLI_COMMAND"
        LOCKED_CELLS=$(eval "$CLI_COMMAND" | egrep instance | tail -1 | awk '{print $1}')
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "cmedit get \* EUtranCellFDD.administrativeState==UNLOCKED --count"'
        _logme "Executing: $CLI_COMMAND"
        UNLOCKED_CELLS=$(eval "$CLI_COMMAND" | egrep instance | tail -1 | awk '{print $1}')

        TOTAL_CELLS_IN_NETWORK=$(echo $LOCKED_CELLS + $UNLOCKED_CELLS | bc)

        _logme ""
        _logme "Status of EUtranCellFDD.administrativeState:- LOCKED:$LOCKED_CELLS UNLOCKED:$UNLOCKED_CELLS"
        _logme ""

}


_check_user_input() {
        if [ "$CONFIRM" == "TRUE" ]; then
                while true; do
                        read -p "Do you wish to proceed? (y/n) " yn
                        case $yn in
                                [Yy]* ) echo "Proceeding"; break;;
                                [Nn]* ) exit;;
                                * ) echo "Please answer yes or no.";;
                        esac
                done
        fi
}


_get_list_of_subnets_in_network() {
        _logme "Getting the list of so-called Subnets"
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "cmedit get \* NetworkElement"'
        _logme "Executing: $CLI_COMMAND"
        LIST_OF_SUBNETS=$(eval "$CLI_COMMAND" | egrep ^FDN | awk -F[=,] '{print $2}' | awk -F'R' '{print $1}' | sort | uniq -c | awk '{print $2}')

}


_precondition_setup() {
        _logme "Ensuring the preconditions are in place for this test"
        _logme "WARNING: This procedure will set the administrativeState for all EUtranCellFDD's in the network to be UNLOCKED"
        _logme "          - it will do this on a per SIM/Subnet basis"
        _logme "This step is necessary because about one third of all cells are LOCKED by default in the simulations delivered"

        _check_user_input

        _get_list_of_subnets_in_network
        _logme "$LIST_OF_SUBNETS"

        _logme
        _logme "Unlocking all cells - 1 sim at a time"
        COUNT=1; 
        for SUBNET in $LIST_OF_SUBNETS; do 
                MESSAGE="$COUNT of $(echo $LIST_OF_SUBNETS | wc -w) $(date)"; 
                _logme "-n $MESSAGE" 
                CMEDIT_COMMAND="cmedit set \*${SUBNET}\* EUtranCellFDD administrativeState=UNLOCKED"
                _logme "$CMEDIT_COMMAND"
                CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "$CMEDIT_COMMAND"'; 
                eval $CLI_COMMAND
                ((COUNT++)); 
                sleep 1
        done

}

_unlock_all_locked_cells() {
        DEPLOYMENT=$(cat /var/ericsson/ddc_data/config/ddp.txt | awk -F'_' '{print $2}')
        _logme "Executing $KPI test:-"

        _logme ""
        _logme "1) Checking Network status BEFORE the test"
        _check_cell_status
        LOCKED_CELLS_BEFORE=$LOCKED_CELLS
        UNLOCKED_CELLS_BEFORE=$UNLOCKED_CELLS



        _logme ""
        _logme "2) Getting KPI value: Measuring the unlock of all locked cells - Note: KPI expects maximum 100 cells as being locked"

        _logme "Unlocking all $LOCKED_CELLS locked cells in the network"
        _check_user_input

        _logme "Start time: $(date)" 
        STARTTIME=$(date +%s);
 
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "cmedit set \* EUtranCellFDD.(administrativeState==LOCKED) administrativeState=UNLOCKED"'; 
        _logme "Executing: $CLI_COMMAND"
        RESULT=$(eval "$CLI_COMMAND")
        _logme "$RESULT"
        TOTAL_CELLS_ACTUALLY_UNLOCKED=$(echo $RESULT | perl -pe 's/.* ([0-9]*) instance.*/$1/')

        _logme "End time: $(date)" 
        ENDTIME=$(date +%s); 

        TOTAL_TIME_TAKEN_IN_SECONDS=$(($ENDTIME - $STARTTIME)); 


        _logme ""
        _logme "3) Checking Network status AFTER the test"
        _check_cell_status
        LOCKED_CELLS_AFTER=$LOCKED_CELLS
        UNLOCKED_CELLS_AFTER=$UNLOCKED_CELLS

        if [ "$(echo $RESULT | egrep Error)" != "" ]; then
                TOTAL_CELLS_ACTUALLY_UNLOCKED=$(echo $LOCKED_CELLS_BEFORE - $LOCKED_CELLS_AFTER | bc)
        fi
        
        _logme ""
        _logme "Result: $TOTAL_CELLS_ACTUALLY_UNLOCKED cells unlocked in $TOTAL_TIME_TAKEN_IN_SECONDS secs"
        


        _logme ""
        _logme "$KPI Summary:-"

        printf "%10s %10s %10s\n" "" "LOCKED" "UNLOCKED"
        printf "%10s %10s %10s\n" "BEFORE" "$LOCKED_CELLS_BEFORE" "$UNLOCKED_CELLS_BEFORE"
        printf "%10s %10s %10s\n" "AFTER" "$LOCKED_CELLS_AFTER" "$UNLOCKED_CELLS_AFTER"

        HOURS=$(($TOTAL_TIME_TAKEN_IN_SECONDS/3600))
        MINUTES=$(($TOTAL_TIME_TAKEN_IN_SECONDS%3600/60))
        SECONDS=$(($TOTAL_TIME_TAKEN_IN_SECONDS%60))

        _logme ""
        SUMMARY="Takes ${HOURS}h.${MINUTES}m.${SECONDS}s to Query/Update $TOTAL_CELLS_IN_NETWORK cells in the network where $TOTAL_CELLS_ACTUALLY_UNLOCKED cells had been changed from LOCKED to UNLOCKED [$DEPLOYMENT at $(date)]" 
        logger INFO "KPI:$KPI Result:$TOTAL_TIME_TAKEN_IN_SECONDS Summary:$SUMMARY"
        _logme $KPI $SUMMARY
        _logme ""


}

_lock_random_cells() {
        CELL_COUNT=$1
        [[ "$CELL_COUNT" == "" ]] && CELL_COUNT=100
        
        _logme "Locking $CELL_COUNT random cells in the network"
        _check_user_input

        if [ "$FILE" == "" ]; then
                _logme "Getting list of all cells"
                FILE_CONTAINING_EUtranCellFDD_FDN_LIST="/ericsson/enm/dumps/EUtranCellFDD.list"
                CMEDIT_COMMAND="cmedit get \* EUtranCellFDD"
                CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "$CMEDIT_COMMAND" ' 
                _logme "-n 'Executing: '"; _logme "$CMEDIT_COMMAND"
                eval "$CLI_COMMAND" > $FILE_CONTAINING_EUtranCellFDD_FDN_LIST
        else 
                if [ -f $FILE ]; then FILE_CONTAINING_EUtranCellFDD_FDN_LIST=$FILE; else _logme "File does not exists: $FILE"; exit 0; fi
        fi

        _logme ""
        _logme "Choosing random cells from $FILE_CONTAINING_EUtranCellFDD_FDN_LIST"
        CELL_LIST=$(egrep ^FDN $FILE_CONTAINING_EUtranCellFDD_FDN_LIST | awk '{print $3}' | sort -R | head -$CELL_COUNT)

        _logme "Setting EUtranCellFDD.administrativeState on $CELL_COUNT cells to be LOCKED - $(date)"
        COUNT=1; 
        NODE_POPULATOR_FILE=/opt/ericsson/enmutils/etc/nodes/rvb-network

        # Remove any artefacts from previous failed runs
        for FILE in $(ls -a $OUTPUT_DIR/ | egrep ".res|.cmd|.check"); do rm -rf $OUTPUT_DIR/$FILE; done

        PIDS=""
        for CELL in $CELL_LIST; do

                NODENAME=$(echo $CELL | perl -pe 's/.*EUtranCellFDD=(.*?)/$1/' | awk -F'-' '{print $1}')
                NETSIM_NODENAME=$(echo $NODENAME | awk -F'_' '{print $NF}')
                CELL_NAME=$(echo $CELL | awk -F'=' '{print $NF}')
                MO=$(echo $CELL | perl -pe 's/.*(ManagedElement=.*)/$1/')
                SIM=$(egrep $NODENAME $NODE_POPULATOR_FILE | awk -F',' '{print $(NF-3)}' | sed 's/ //g')
                NETSIM=$(egrep $NODENAME $NODE_POPULATOR_FILE | awk -F',' '{print $(NF-2)}' | sed 's/ //g')

                _logme "$COUNT:- Netsim: $NETSIM  Simulation:$SIM  Node:$NODENAME  Cell:$CELL_NAME"

                #Want to connect to Netsim and run the commands there
                FILENAME=".stkpi_CMCLI_01.$COUNT.$NETSIM.$SIM.$NETSIM_NODENAME.$CELL_NAME"
                echo ".open $SIM" > $OUTPUT_DIR/$FILENAME.cmd
                echo ".select $NETSIM_NODENAME" >> $OUTPUT_DIR/$FILENAME.cmd 
                echo "setmoattribute:mo=\"$MO\", attributes=\"administrativeState=0\";" >> $OUTPUT_DIR/$FILENAME.cmd


                # Check
                echo "ssh netsim@$NETSIM 'echo \"dumpmotree:moid=\\\"$MO\\\",printattrs;\" | /netsim/inst/netsim_pipe -sim $SIM -ne $NETSIM_NODENAME' | egrep administrativeState" > $OUTPUT_DIR/$FILENAME.check


                #Ensure passwordless access to $NETSIM
                /root/rvb/copy-rsa-key-to-remote-host.exp $NETSIM netsim

                #Copy mml script to $NETSIM which will lock the cell
                scp $OUTPUT_DIR/$FILENAME.cmd netsim@$NETSIM:/var/tmp > /dev/null 

                #Lock the cell via Netsim pipe
                ssh netsim@$NETSIM "cat /var/tmp/$FILENAME.cmd | /netsim/inst/netsim_pipe; rm -rf /var/tmp/$FILENAME.cmd" > $OUTPUT_DIR/$FILENAME.res &
                PIDS="$PIDS $!"


                #echo "$COUNT:- Netsim: $NETSIM  Simulation:$SIM  Node:$NODENAME  Cell:$MO" > $OUTPUT_DIR/.stkpi_CMCLI.$COUNT.$CELL
                #/opt/ericsson/enmutils/bin/netsim cli $NETSIM $SIM $NETSIM_NODENAME "setmoattribute:mo=\"$MO\", attributes=\"administrativeState=1\";" >> $OUTPUT_DIR/.stkpi_CMCLI.$COUNT.$CELL &

                sleep 2


                ((COUNT++)); 
        done
        wait $PIDS

        # Log the result of the netsim command execution
        for FILE in $(ls $OUTPUT_DIR/.*.res); do
                FILENAME=$(basename $FILE)
                _logme "$(echo ${FILENAME%.*})"
                _logme "$(cat $FILE)"
        done


        _logme "Complete - $(date)"

}


# If no arguments passed to this script, then display help message, and exit
[[ $# == 0 ]] && _displayHelpMessage

_initialize_logfile

CONFIRM=TRUE
# Process the different options passwed to script
while getopts "nspul:hd" opt; do
    case $opt in
        n ) CONFIRM=FALSE;;
        s ) _check_network_sync_status; _check_cell_status  ;;
        p ) _precondition_setup ;;
        u ) _unlock_all_locked_cells ;;
        l ) CELLS=$OPTARG
            shift $((OPTIND - 1))  
            [[ $# -gt 0 ]] && if [ "$1" == "-f" ]; then shift; FILE=$1; fi 
            _lock_random_cells $CELLS;; 
        h ) _displayHelpMessage; exit 0 ;;
        d ) _about; exit 0;;
        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
    esac
done



