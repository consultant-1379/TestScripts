#!/bin/bash

# Script to get a listing of all pm & symlink files 
#  - this is needed until PMIC attains a consistent level of stability around file collection
#    e.g. to assist with troubleshooting problems as described in TORF-94034

sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'

# Enable passwordless root ssh access to mspm VMs as gonna run a find command against each one
MSPM_NODE_LIST=$(litp show -p /deployments/enm/clusters/svc_cluster/services/mspm | egrep node_list | awk '{print $NF}' | sed 's/,/ /g' | sort)


# Grab the file listings - takes about 30 to 35 mins
PMIC_DATA_DIR="/ericsson/enm/dumps/PMIC_DATA_DIR"
mkdir -p $PMIC_DATA_DIR

# Different number of PM volumes in 16.1 (3 volumes) and 16.2 onwards (2 volumes)
[[ -z $1 ]] && MAX_PMIC_VOL_COUNT=2 || MAX_PMIC_VOL_COUNT=3

DATE_OF_EXECUTION=$(date +%y%m%d)
TIME_OF_EXECUTION=$(date +%H%M%S)
COUNT=0
for SVC in $MSPM_NODE_LIST; do
	# initialize communication towards mspm instance, in the event that there was upgrade and keys no longer valid
	$sshvm $SVC-mspm "date" 

        if [ $COUNT -eq 0 ]; then
                FILENAME=$PMIC_DATA_DIR/symvol.file_list.timestamps.$DATE_OF_EXECUTION
                [[ -f $FILENAME ]] && FILENAME="$FILENAME.$TIME_OF_EXECUTION"
                $sshvm $SVC-mspm "find /ericsson/symvol/ -type l -mmin -$((60*24)) -exec ls -l --full-time {} \; > $FILENAME &"
                ((COUNT++))
                continue
        fi

        if [ $COUNT -le $MAX_PMIC_VOL_COUNT ]; then
                FILENAME=$PMIC_DATA_DIR/pmic$COUNT.file_list.timestamps.$DATE_OF_EXECUTION
                [[ -f $FILENAME ]] && FILENAME="$FILENAME.$TIME_OF_EXECUTION"
                $sshvm $SVC-mspm "find /ericsson/pmic$COUNT/ -type f -mmin -$((60*24)) -exec ls -l --full-time {} \; > $FILENAME &"
        fi

        ((COUNT++))

done



# Compress the older file listing 'snapshots' to prevent a buildup of space used over time
for FILE in $(ls $PMIC_DATA_DIR/ | egrep file_list.timestamps | egrep -v gz | egrep -v $(date +%y%m%d)); do
        gzip $PMIC_DATA_DIR/$FILE &
done


# Delete files older than 2 weeks
find $PMIC_DATA_DIR -mtime +14 -delete

