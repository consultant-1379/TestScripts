#!/bin/sh
mkdir /dev/shm/PM_NBI/

TMP_FILE_DIR=/dev/shm/PM_NBI/

logger "INFO PM_NBI: Starting Shuffle"

find /ericsson/pmic1/XML/ -type f | shuf -n 4000 | xargs cp -t $TMP_FILE_DIR

find /ericsson/pmic2/XML/ -type f | shuf -n 4000 | xargs cp -t $TMP_FILE_DIR

find /ericsson/pmic1/CELLTRACE/ -type f | shuf -n 4000 | xargs cp -t $TMP_FILE_DIR

find /ericsson/pmic2/CELLTRACE/ -type f | shuf -n 4000 | xargs cp -t $TMP_FILE_DIR

logger "INFO PM_NBI: Shuffle Ended"

FILE_COUNT=`ls -l $TMP_FILE_DIR | wc -l`
FOLDER_SIZE=`du -Sh $TMP_FILE_DIR | awk '{ print $1}'`

logger "INFO PM_NBI: Folder Size:" $FOLDER_SIZE
logger "INFO PM_NBI: Number of Files:" $FILE_COUNT

# Lets delete anything greater than 45 mins old
find  /dev/shm/ -type f -mmin +15|xargs rm -f



