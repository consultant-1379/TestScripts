#!/bin/bash

if [ -z $1 ]
then
        echo "Need to specify   NETSIM   NODE  [  XML  |  CELL  ]" 
        exit 0
fi

NETSIM=$1
NODE=$2
SIM=$(echo $NODE | cut -c1-5)

DATE=$(date -u "+%s");
LAST_ROP_START=$(date -u -d"@$(($DATE - ($DATE % (15 * 60)) - (15*60)))" "+%H%M")
LAST_ROP_END=$(date -u -d"@$(($DATE - ($DATE % (15 * 60))))" "+%H%M")
LAST_ROP_DATE=$(date -u +%Y%m%d)

CURRENT_ROP_END=$(date -u -d"@$(($DATE - ($DATE % (15 * 60)) + (15*60)))" "+%H%M")

PM_DIR=/pms_tmpfs/$SIM/$NODE/c/pm_data

if [ "$3" == "XML" ]; then
        COMMAND="ls -lh $PM_DIR/A${LAST_ROP_DATE}.${LAST_ROP_END}-${CURRENT_ROP_END}:1.xml.gz"
else
        COMMAND="ls -lh $PM_DIR/A${LAST_ROP_DATE}.${LAST_ROP_START}-${LAST_ROP_END}_CellTrace_DUL1_3.bin.gz"
fi

echo "Command used: # ssh netsim@$NETSIM $COMMAND"

ssh netsim@$NETSIM $COMMAND

