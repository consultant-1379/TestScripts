#!/bin/bash

printf "\nScript to check the actual transfer rate across network, using 1 node per sim\n"

CHECK_RATE_PER_NODE_SCRIPT="check_sftp_transfer_rate_per_node.sh"


# Check input parameters (simple check)
if [ $# -lt 2 ]; then
        echo
        echo "USAGE: $0 ipaddress_file nodename [ XML | CELL ]"
        echo " (e.g. $(basename $0) /ericsson/enm/dumps/nodes.cpp.ipaddress ERBS00160 )"
        echo
        echo " Notes:-"
        echo "  1) Script needs to be run from mspm instance "
        echo "  2) Create ipaddress file with "
        echo "        e.g. /opt/ericsson/enmutils/bin/cli_app 'cmedit get * CppConnectivityInformation.ipAddress' | egrep '^FDN|^ip' | paste - - > /ericsson/enm/dumps/nodes.cpp.ipaddress "
        echo "  3) Specify XML or CELL to check the file transfer rate for these different types of files. Default selected is CELL"
        echo
        exit 0
fi

# Check if running this from mspm
if [ -z $(echo $(hostname) | egrep mspm$) ]; then
        echo "Script needs to be run from mspm instance"
        echo 
        exit 0
fi


if [ ! -f $1 ]; then
        echo "ipaddress file doesnt exist: $NODE_FILE - check usage"
        exit 0
fi


NODE_FILE=$1
NODE_NUMBER=$2
[[ "$3" == "" ]] && TYPE=CELL || TYPE=$3 
DIR=$(dirname $0)
SUMMARY_FILE=/var/tmp/rvb_transfer_rate_summary.$(date +%y%m%d.%H%M%S)

echo
echo "Checking sftp transfer rate for file type: $TYPE"

printf "\nNote: Can check individual nodes with: $DIR/$CHECK_RATE_PER_NODE_SCRIPT \n"
printf "%-6s %-35s %-35s %-10s\n" "TYPE" "NODE_NAME" "NODE_IP" "TRANSFER_RATE" > $SUMMARY_FILE


# For every node, get the IP from the file above and check the transfer rate
LIST_OF_NODE_NAMES=$(egrep $NODE_NUMBER $NODE_FILE | awk -F[=,] '{print $2}' | sort)
for NODE_NAME in $LIST_OF_NODE_NAMES
do
        NODE_IP=$(egrep $NODE_NAME $NODE_FILE | awk '{print $NF}')
        OUTPUT_FILE="/var/tmp/rvb_transfer_rate.$NODE_NAME"
        printf "%-6s %-35s %-35s " $TYPE $NODE_NAME $NODE_IP > $OUTPUT_FILE
        $DIR/$CHECK_RATE_PER_NODE_SCRIPT $NODE_IP $TYPE | egrep '^Transfer' | awk '{print $NF}' >> $OUTPUT_FILE &
        PIDS="$PIDS $!"
done

wait $PIDS


cat /var/tmp/rvb_transfer_rate.* >> $SUMMARY_FILE
cat $SUMMARY_FILE
rm -rf /var/tmp/rvb_transfer_rate.*

echo
echo "Results stored here on $(hostname) at $SUMMARY_FILE"
echo


