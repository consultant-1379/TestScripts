#!/bin/bash

if [ -z $1 ]
then
        echo "Need to specify NODE_IP [ XML | CELL ] [ DEBUG ]" 
        exit 0
fi

if [ "$3" == "DEBUG" ]
then
        DEBUG="-d"
fi

NODE_IP=$1
# Cater for IPv6 special handling, i.e. need to add square brackets before and after the IP
if [ ! -z $(echo $NODE_IP | egrep :) ]; then
        NODE_IP="\[$NODE_IP\]"
fi

DATE=$(date -u "+%s");
LAST_ROP_START=$(date -u -d"@$(($DATE - ($DATE % (15 * 60)) - (15*60)))" "+%H%M")
LAST_ROP_END=$(date -u -d"@$(($DATE - ($DATE % (15 * 60))))" "+%H%M")
LAST_ROP_DATE=$(date -u +%Y%m%d)

CURRENT_ROP_END=$(date -u -d"@$(($DATE - ($DATE % (15 * 60)) + (15*60)))" "+%H%M")

if [ "$2" == "XML" ]; then
        FILENAME="A${LAST_ROP_DATE}.${LAST_ROP_END}-${CURRENT_ROP_END}*.xml.gz"
else
        FILENAME="A${LAST_ROP_DATE}.${LAST_ROP_START}-${LAST_ROP_END}_CellTrace_DUL1_3.bin.gz"
fi

COMMAND="sftp netsim@$NODE_IP:/c/pm_data/$FILENAME /var/tmp/${NODE_IP}_${FILENAME} "
echo "Command used: $COMMAND"


OUTPUT=$(/usr/bin/expect $DEBUG << EOF
set password "netsim"
set timeout 15

spawn -noecho /bin/sh -c "$COMMAND"

expect {
        "Are you sure you want to continue connecting (yes/no)? " {
                send "yes\r"
                exp_continue

        } "assword: " {
                send "netsim\r"
                exp_continue

        } "No such file or directory" {
                puts "FileNotFound . ."
                exit 0
        }
}

EOF

)

rm -rf /var/tmp/${NODE_IP}_${FILENAME}
echo "Transfer Rate: $( echo $OUTPUT | awk '{print $(NF-2)}' )"

