#!/bin/bash

echo "Script to make backup of jboss logfiles"

echo " To exit - (#touch /tmp/.stop_backup) or CTRL + C "

LOGDIR="/ericsson/3pp/jboss/standalone/log/"
LOGFILE=server.log
LOGBACKUPDIR="$LOGDIR/LOGBACKUP.$(date +%y%m%d.%H%M%S)"
echo "Logs being stored here: $LOGBACKUPDIR"
mkdir -p $LOGBACKUPDIR 2> /dev/null

trap exit_me INT
#will be called on CTRL + C 
function exit_me() {
        echo "====================================================================="
        echo "Note - CTRL + C is pressed, catching the last trace file and exiting...."
        echo "Please stop the trace if not needed anymore.."
        echo "====================================================================="
        TIME=$(date +%y%m%d.%H%M%S)
        exit 1
}

for FILE in $(ls $LOGDIR | egrep $LOGFILE.[2345]); 
do 
        mv $LOGDIR/$FILE $LOGBACKUPDIR/
        gzip $LOGBACKUPDIR/$FILE &
done

while true; do
        if [[ -f "/tmp/.stop_backup" ]]; then
                rm /tmp/.stop_backup 2> /dev/null
            exit 1
        fi
        if [[ -e "$LOGDIR/$LOGFILE.1" ]]; then
                TIME=$(date +%y%m%d.%H%M%S)
                /bin/mv $LOGDIR/$LOGFILE.1 $LOGBACKUPDIR/$LOGFILE.$TIME
                /bin/gzip $LOGBACKUPDIR/$LOGFILE.$TIME &
        fi
done

