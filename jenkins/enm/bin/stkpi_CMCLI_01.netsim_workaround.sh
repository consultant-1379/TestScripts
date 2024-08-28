#!/bin/bash

MO="ManagedElement=1,SystemFunctions=1,Licensing=1,OptionalFeatures=1,CombinedCell=1"
ATTR="serviceStateCombinedCell"
NEW_VALUE="1"

ARG=$1
[[ -z $ARG ]] && { 
        echo
        echo "This script is to be use to workaround the issue reported here: NS-5786"
        echo "https://jira-nam.lmera.ericsson.se/browse/NS-5786"
        echo "This is necessary to support the script ../stkpi_CMCLI_01.sh"
        echo
        echo "The script works by setting attribute CombinedCell.serviceStateCombinedCell in simulation"
        echo " to allow attributre EUtranCellFDD.administrativeState to be changed via netsim command setmoattribute"
        echo " eventhough the attribute EUtranCellFDD.sectorCarrierRef has references to multiple SectorCarrier MO's"
        echo
        echo "Location of MO: $MO"
        echo "Note: DG2 simulations dont appear to have this MO and so sims with 'dg2' in the name are excluded by this script"
        echo
        echo "For more details, see this TR: NS-2026 "
        echo "https://jira-nam.lmera.ericsson.se/browse/NS-2026"
        echo
        echo "Usage: $0  { cluster_id  | netsim_machine_name }"
        echo "No argument specified...exiting"
        echo
        exit 0
}


# Create MML FILE to be run against simulation
NETSIM_MML_FILE="/var/tmp/setmoattribute.serviceStateCombinedCell"
echo ".select network" > $NETSIM_MML_FILE
echo "setmoattribute:mo=\"$MO\", attributes=\"$ATTR=$NEW_VALUE\";" >> $NETSIM_MML_FILE 



if [ ! -z $(echo $ARG | egrep netsim ) ]; then
        #Assume that netsim machine is being passed to script
        NETSIM_LIST=$ARG
else
        # Assume that it's an actual CLUSTERID being passed"
        CLUSTERID=$ARG
        CONF_FILE="/root/rvb/deployment_conf/5${CLUSTERID}.conf"
        NETSIM_LIST=$(egrep netsim $CONF_FILE | awk -F[\":] '{print $2}')
fi


for NETSIM in $NETSIM_LIST; do
        echo "Enable passwordless ssh access to $NETSIM for netsim user"
        /root/rvb/copy-rsa-key-to-remote-host.exp $NETSIM netsim
        echo

        echo "Getting list of non-dg2 SIMS on $NETSIM"
        SIMS=$(ssh netsim@$NETSIM ls -l /netsim/netsimdir/ | egrep LTE | egrep -iv 'dg|zip' | awk '{print $NF}' )
        echo $NETSIM:$SIMS; 
        echo

        echo "Copying MML FILE to $NETSIM"
        scp $NETSIM_MML_FILE netsim@$NETSIM:$NETSIM_MML_FILE
        echo

        echo "Setting attribute $ATTR=$NEW_VALUE in MO: $MO"
        for SIM in $SIMS; do
                echo "SIM: $SIM"
                ssh netsim@$NETSIM "cat $NETSIM_MML_FILE | /netsim/inst/netsim_shell -sim $SIM" &
                PIDS="$PIDS $!"
        done
        echo "Waiting for netsim processes to complete..."
        wait $PIDS
        echo "...done"

done

