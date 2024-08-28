#!/bin/bash 

CLUSTER_ID=$1; 
[[ -z $CLUSTER_ID ]] && { echo "Need to supply CLUSTER_ID"; echo "Usage: $0 CLUSTER_ID"; exit 0; }

FILE="/root/rvb/deployment_conf/5${CLUSTER_ID}.conf"

[[ ! -f $FILE ]] && { echo "Problem with CLUSTER_ID entered"; echo "File does not exist: $FILE ... Exiting"; exit 0; }

echo "Checking number of started nodes on netsims listed in $FILE ..."

PIDS=""
for NETSIM in $(egrep netsim $FILE | awk -F[\":] '{print $2}'); do
	/root/rvb/copy-rsa-key-to-remote-host.exp $NETSIM netsim
        LIST_STARTED_NODES="echo '.show started' | /netsim/inst/netsim_pipe | egrep netsimdir"
        LIST_SIMS="ls /netsim/netsimdir/ | egrep 'LTE|CORE|RNC' | egrep -v zip | perl -pe 's/.*-(.*)\$/\$1/' | sort | tr '\n' '_' | sed 's/_\$//'"
        LIST_SIM_NAMES="ls /netsim/netsimdir/ | egrep 'LTE|CORE|RNC' | egrep -v zip | sort | tr '\n' ',' | sed 's/,\$//'"
	NETSIM_COMMAND="NODES='/var/tmp/nodes.started'; $LIST_STARTED_NODES > \$NODES; echo \"\$(egrep -c LTE \$NODES) \$(egrep -c RNC \$NODES) \$(egrep -c CORE \$NODES) \$($LIST_SIMS) \$($LIST_SIM_NAMES)\" "
        echo  "${NETSIM%%.*}: $(ssh netsim@$NETSIM $NETSIM_COMMAND)" | awk '{printf "%-25s LTE: %-5d  WRAN: %-5d  CORE: %-5d  SIMS: %-25s  NAMES: %s\n", $1, $2, $3, $4, $5, $6}' &
	PIDS="$PIDS $!" 
done
wait $PIDS

