#!/bin/sh

printf "\nScript to check the actual transfer rate across network, using 1 node per sim\n"

CHECK_SIZE_PER_NODE_SCRIPT="check_pm_file_size_per_node.sh"


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

# Check if running this from LMS 
service litpd status
if [ $? -ne 0 ]; then
        echo "Script needs to be run from LMS "
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

echo
echo "Checking sftp transfer rate for file type: $TYPE"

printf "\nNote: Can check individual nodes with: $DIR/$CHECK_SIZE_PER_NODE_SCRIPT \n"
printf "%-35s %-35s %-10s\n" "NETSIM" "NODENAME" "FILESIZE"


# For every node, get the IP from the file above and check the transfer rate
LIST_OF_NODE_NAMES=$(egrep $NODE_NUMBER $NODE_FILE | awk -F[=,] '{print $2}' | sort)
for NODE_INFO in $LIST_OF_NODE_NAMES
do
        NODENAME=$(echo $NODE_INFO | awk -F'_' '{print $2}')
        NETSIM=$(echo $NODE_INFO | awk -F'_' '{print $1}')
        FILESIZE=$($DIR/$CHECK_SIZE_PER_NODE_SCRIPT $NETSIM $NODENAME $TYPE | egrep 'netsim netsim' | awk '{print $5}')
        printf "%-35s %-35s %-10s\n" $NETSIM $NODENAME $FILESIZE
done

