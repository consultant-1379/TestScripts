#!/bin/bash

DUMPS="/ericsson/enm/dumps"
STORAGE_LOCATION="$DUMPS/VCS_NODE_LOGS/"

echo ""
echo "Script to grab the server logs (messages files and engine logs) from all vcs nodes"
echo "(printouts are stored in $STORAGE_LOCATION)"

sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'



_displayHelpMessage() {
        echo 
        echo "Usage: $0 { -a | -n <node> | -c <cluster> } "
        echo 
        echo "Examples:"
        echo "    1) Grab server logs from all nodes in all clusters:"
        echo "    # $0 -a "
        echo 
        echo "    2) Grab server logs from just 1 node:"
        echo "    # $0 -n svc-1 "
        echo 
        echo "    3) Grab server logs from all nodes in 1 cluster:"
        echo "    # $0 -c svc"
        echo 

        exit 0
}

_create_artefacts() {
        # Create directory on SFS to store output
        mkdir -p $STORAGE_LOCATION

        # Create file on SFS to be sourced on the VM in order to grab the logs 
        COMMAND_FILE=$DUMPS/.scripts/.collect_server_logs_on_vcs_nodes

        if [ ! -f $COMMAND_FILE ]; then

                echo '
                DIR=$(pwd)/$(hostname)/$(date +%y%m%d.%H%M%S); 
                mkdir -p $DIR; 
                cp -p /var/log/messages* $DIR/
                cp -p /var/VRTSvcs/log/engine_A.log $DIR/
                gzip $DIR/* &

                ' > $COMMAND_FILE

        fi
}

_collect_all() {
        CLUSTERS=$(litp show -p /deployments/enm/clusters/ | egrep _cluster | awk -F[/_] '{print $2}')
        for CLUSTER in $CLUSTERS
        do
                NODES=$(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes | egrep '/.*-' | awk -F'/' '{print $2}')
                for NODE in $NODES
                do 
                        NODE_LIST="$NODE_LIST $NODE"
                done
        done
}

_collect_cluster() {
        NODES=$(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes | egrep '/.*-' | awk -F'/' '{print $2}')
        for NODE in $NODES
        do 
                NODE_LIST="$NODE_LIST $NODE"
        done

        echo "$CLUSTER instances: $NODE_LIST"; 
}

_collect_node() {
        NODE_LIST=$NODE
        echo "$NODE instance"; 
}



# If no arguments passed to this script, then display help message, and exit
[[ $# == 0 ]] && _displayHelpMessage


# Process the different options passwed to script
while getopts "an:c:h" opt; do
    case $opt in
        a ) _collect_all ;;
        n ) NODE=${OPTARG}; _collect_node ;;
        c ) CLUSTER=${OPTARG}; _collect_cluster ;;
        h ) displayHelpMessage; exit 0 ;;
        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
    esac
done


_create_artefacts


echo ""
echo -n "Grab server logs for ";

# ssh to each VM in NODE_LIST and grab the server logs    
for NODE in $NODE_LIST; do 
        echo $NODE $(date); 
        $sshvm $NODE "cd $STORAGE_LOCATION; . $COMMAND_FILE"; 
        if [ $? -ne 0 ]; then echo "Problem connecting to $NODE with ssh...exiting"; exit 0; fi
        echo "Logs stored at: $STORAGE_LOCATION"
        echo
done;    


