#!/bin/sh

USER="cloud-user"
#PASSWORD="testing"
HOST="scp-1-scripting"
EXPECT=/usr/bin/expect
TMP_FILE_DIR=/dev/shm/PM_NBI/
mkdir /dev/shm/PM_NBI/
cd /dev/shm/PM_NBI/
cd $TMP_FILE_DIR
find  /dev/shm/ -type f -mmin +20|xargs rm -f
logger "INFO PM_NBI: Clean up directory for next sftp"
rm -rf /dev/shm/PM_NBI/*
logger "INFO PM_NBI: Starting sftp"

VAR1=`cat << EOF
        spawn sftp -oIdentityFile=/root/.ssh/vm_private_key $USER@$HOST
        expect -exact {
        Connecting to $HOST...\r
        ###########  WARNING  ############\r
        \r
        This system is for authorised use only. By using this system you consent to monitoring and data collection.\r
        \r
        ##################################\r
        $USER@$HOST\'s password:
        }
        send -- "\r"
        expect -exact "\r
        sftp> "
        send -- "cd $TMP_FILE_DIR\r"
        expect -exact "cd $TMP_FILE_DIR\r
        sftp> "
	set timeout 240
        send -- "get *\r"
        expect -exact "get *\r
        sftp> "
        send -- "bye\r"
        expect -exact "bye\r"
EOF`

$EXPECT -c "$VAR1"

FILE_COUNT=`ls -l $TMP_FILE_DIR | wc -l`
FOLDER_SIZE=`du -Sh $TMP_FILE_DIR | awk '{ print $1}'`

logger "INFO PM_NBI: Ending sftp"
logger "INFO PM_NBI: Folder Size:" $FOLDER_SIZE
logger "INFO PM_NBI: Number of Files:" $FILE_COUNT
#logger "INFO PM_NBI: Clean up directory for next sftp"
cd /dev/shm/PM_NBI/
#rm -rf *
