#!/bin/bash

echo
echo "Script to take regular snapshots of Versant lock information"
echo

DBTOOL="/ericsson/versant/bin/dbtool"
DB=dps_integration
HOSTNAME=$(hostname)
OUTPUTDIR="/ericsson/enm/dumps/VERSANT_LOCK_DEBUG/$HOSTNAME"

if [ "$(whoami)" != "root" ]; then
        echo "Need to run this as root ... exiting"
        exit 0
fi


if [ $# -ne 1 ]; then

        DATE=$(date +%y%m%d.%H%M%S)
        COMMAND1="su - versant -c \"$DBTOOL -locks -table $DB\" "
        COMMAND2="su - versant -c \"$DBTOOL -locks -stats $DB\" "
        COMMAND3="su - versant -c \"$DBTOOL -locks -info  $DB\" "

        echo "- snapshots will be taken every X secs until script is interrupted"
        echo "Usage: $0 time_interval"
        echo "where "
        echo " time_interval        Gap between each set of the dbtool snapshots"
        echo 
        echo "Note1: Use CTRL+C to interrupt"
        echo "Note2: Can only be run on DB node where versant obe process is running"
        echo
        echo "Set of commands to be executed:-" 
        echo "$COMMAND1 > $OUTPUTDIR/$DB.locks_table.\$(date +%y%m%d.%H%M%S)"
        echo "$COMMAND2 > $OUTPUTDIR/$DB.locks_stats.\$(date +%y%m%d.%H%M%S)"
        echo "$COMMAND3 > $OUTPUTDIR/$DB.locks_info.\$(date +%y%m%d.%H%M%S)"
        echo
        exit 0
fi

GAP=$1
if [ "$GAP" == "0" ]; then
        echo "time_interval = 0 is not allowed"
        exit 0
fi

VERSANT_OBE_PID=$(pgrep obe)
if [ "$VERSANT_OBE_PID" == "" ]; then
        echo "Script needs to be run on the blade where the versant obe process is running ... exiting"
        echo "Check that process is running with command 'pgrep obe'"
        exit 0
fi


trap exit_me INT
#will be called on CTRL + C 
function exit_me() {
        echo "Note: CTRL+C is pressed ... exiting"
        #TODO: zip unzipped files - /usr/bin/gzip $OUTPUTDIR/$DB.locks.* 
        echo "Snapshot files are stored here: $OUTPUTDIR"
        exit 1
}

mkdir -p $OUTPUTDIR
COUNT=1
while [ true ]; 
do 
        DATE=$(date +%y%m%d.%H%M%S)

        su - versant -c "$DBTOOL -locks -table $DB" > $OUTPUTDIR/$DB.locks_table.$DATE
        su - versant -c "$DBTOOL -locks -stats $DB" > $OUTPUTDIR/$DB.locks_stats.$DATE
        su - versant -c "$DBTOOL -locks -info $DB" > $OUTPUTDIR/$DB.locks_info.$DATE

        gzip $OUTPUTDIR/$DB.locks_table.$DATE &
        gzip $OUTPUTDIR/$DB.locks_stats.$DATE &
        gzip $OUTPUTDIR/$DB.locks_info.$DATE &

        printf "$DATE - $COUNT\r"
        sleep $GAP; 
        ((COUNT++))
done

echo 

