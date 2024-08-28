#!/bin/bash

source ~/.bashrc

KPI=STKPI_CM_Change_01
TITLE="On a Node change one attribute on existing MO for all eNBs"
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
        echo "$KPI:$TITLE"
        echo "Usage: $0 [ -n ] {-s managed_object | -u managed_object | -h | -d }"
        echo ""
        echo "where"
        echo " -n               No confirmation - Dont ask for permission before setting the values"
        echo " -s MO            Status - Check the current value, across the network, of the userLabel attribute for the specified MO"
        echo " -u MO            Update - Set the value of the userLabel attribute for the specified managed_object, ie MO, to the current date_time"
        echo "                      e.g. $0 -s ENodeBFunction" 
        echo " -h               Help - display this message"
        echo " -d               Description - display info about this KPI"
        echo 
        exit 0
}

_about() {

echo "

Title
=====
$TITLE

Description
===========
It should be possible to change an existing attribute across 5k ENodeBs  
Requirement: Completes within 5 minutes

EEIDBN: 'I would say test with 10.5 k but double the time allowed' (2016-02-01)

"

}

_logme() {
        MESSAGE=$1
        echo "$MESSAGE"
        echo "$MESSAGE" >> $LOGFILE
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


_check_network_sync_status() {
        _logme "Checking Node sync status"
        COMMAND="/opt/ericsson/enmutils/bin/network sync-status"
        _logme "Executing $COMMAND"
        eval $COMMAND

}


_check_current_value_of_mo_userlabel() {
        MO=$1
        _logme "Checking the current value of $MO.userLabel across the network - $(date)"
        # CMEDIT_COMMAND="cmedit get \* $MO.userLabel"
        CMEDIT_COMMAND="cmedit get * $MO.userLabel"
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "$CMEDIT_COMMAND"'
        _logme "Executing: $CMEDIT_COMMAND"

        _logme "$(date)"
        _logme "#Nodes  userLabel : Value"
        _logme "========================="

        if [ "$VALUE" == "" ]; then
                RESULT=$(eval "$CLI_COMMAND" | egrep '^userLabel' | sort | uniq -c)
                _logme "$RESULT"
                return 1
        else
                VALUE_COUNT=$(eval "$CLI_COMMAND" | egrep '^userLabel' | egrep -c $VALUE)
                return $VALUE_COUNT
        fi
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


_set_attribute_in_all_nodes() {

        MO=$1

        _logme "$TITLE"

        _check_user_input

        VALUE=$(date +%y%m%d_%H%M%S); STARTTIME=$(date +%s);

      #   CMEDIT_COMMAND="cmedit set \* $MO userLabel=$VALUE"
        CMEDIT_COMMAND="cmedit set * $MO userLabel=$VALUE"
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "$CMEDIT_COMMAND"'; 
        _logme "Executing $CMEDIT_COMMAND - $(date)"
        RESULT=$(eval "$CLI_COMMAND" | tail)
        _logme "$RESULT"

        ENDTIME=$(date +%s);
        TOTAL_TIME_TAKEN_IN_SECONDS=$(($ENDTIME - $STARTTIME)); 

        _logme ""
        _logme "Verify attribute has been set"
        # CMEDIT_COMMAND="cmedit get \* $MO.userLabel==$VALUE --count"
        CMEDIT_COMMAND="cmedit get * $MO.userLabel==$VALUE --count"
        CLI_COMMAND='/opt/ericsson/enmutils/bin/cli_app "$CMEDIT_COMMAND"';    
        _logme "Executing: $CMEDIT_COMMAND "
        RESULT=$(eval "$CLI_COMMAND")
        _logme "$RESULT"
        NUMBER_OF_FDNs_UPDATED=$(echo $RESULT | tail -1 | awk '{print $(NF-1)}') 



        _logme ""
        _logme "$KPI Summary:-"

        DEPLOYMENT=$(cat /var/ericsson/ddc_data/config/ddp.txt | awk -F'_' '{print $2}')

        HOURS=$(($TOTAL_TIME_TAKEN_IN_SECONDS/3600))
        MINUTES=$(($TOTAL_TIME_TAKEN_IN_SECONDS%3600/60))
        SECONDS=$(($TOTAL_TIME_TAKEN_IN_SECONDS%60))

        _logme ""
        SUMMARY="Takes ${HOURS}h.${MINUTES}m.${SECONDS}s to change one attribute ($MO.userLabel) on $NUMBER_OF_FDNs_UPDATED eNBs [$DEPLOYMENT at $(date)]" 
        logger INFO "KPI:$KPI Result:$TOTAL_TIME_TAKEN_IN_SECONDS Summary:$SUMMARY"
        _logme "$KPI $SUMMARY"
        _logme ""

}


# If no arguments passed to this script, then display help message, and exit
[[ $# == 0 ]] && _displayHelpMessage

_initialize_logfile

CONFIRM=TRUE
# Process the different options passwed to script
while getopts "ns:u:hd" opt; do
    case $opt in
        n ) CONFIRM=FALSE;;
        s ) _check_network_sync_status; _check_current_value_of_mo_userlabel ${OPTARG};;
        u ) _set_attribute_in_all_nodes ${OPTARG} ;;
        h ) _displayHelpMessage; exit 0 ;;
        d ) _about; exit 0 ;;
        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
    esac
done


