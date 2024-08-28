#!/bin/bash
mkdir -p /var/rvb/network
rm -f /var/rvb/network/*

NETWORK=("ieatnetsimv5051-01.athtem.eei.ericsson.se:"
         "ieatnetsimv5051-02.athtem.eei.ericsson.se:"
         "ieatnetsimv5051-03.athtem.eei.ericsson.se:"
	     "ieatnetsimv5051-04.athtem.eei.ericsson.se:"
	     "ieatnetsimv5051-05.athtem.eei.ericsson.se:"
	     "ieatnetsimv5051-06.athtem.eei.ericsson.se:"
         "ieatnetsimv5051-07.athtem.eei.ericsson.se:"
         "ieatnetsimv5051-09.athtem.eei.ericsson.se:")


# Restart the netsim host
for SEGMENT in ${NETWORK[@]}; do
    NETSIM_HOST=$(echo $SEGMENT | cut -f1 -d:)
    /opt/ericsson/enmutils/bin/netsim restart_netsim $NETSIM_HOST
done

# Wait for all simulations to start successfully
# We have to do this because the netsims are flaky pieces of junk
RC=1
COUNTER=0
while [[ $RC != 0 && $COUNTER -lt 5 ]]; do
    COUNTER=$((COUNTER+1))
    sleep 30
    echo "ATTEMPT #${COUNTER} to start simulations on $NETSIM_HOST..."
    /opt/ericsson/enmutils/bin/netsim start $NETSIM_HOST
    RC=$?
done

# Ensure the fm & cm alarm bursts on the netsim simulations are stopped
for SEGMENT in ${NETWORK[@]}; do
    NETSIM_HOST=$(echo $SEGMENT | cut -f1 -d:)
    SIMS=$(echo $SEGMENT | cut -f2 -d:)

    # If there we no simulations specified we need to get a list of all the simulations from the netsim host
    if [ -z "$SIMS" ]; then
        SIMS=$(/opt/ericsson/enmutils/bin/netsim list $NETSIM_HOST | grep '[0-9]-' | sed 's/ //g' | sed -r 's:\x1B\[[0-9;]*[mK]::g')
    fi

    for SIM in $(echo $SIMS | sed "s/,/ /g"); do
        echo "Stopping all alarm bursts on $NETSIM_HOST $SIM"
        /opt/ericsson/enmutils/bin/netsim cli $NETSIM_HOST $SIM all 'stopburst:id=all;'
    done
done

# Fetch network
set -ex
for SEGMENT in ${NETWORK[@]}; do
    NETSIM_HOST=$(echo $SEGMENT | cut -f1 -d:)
    SIMS=$(echo $SEGMENT | cut -f2 -d:)
    /opt/ericsson/enmutils/bin/netsim fetch $NETSIM_HOST $SIMS /var/rvb/network
done

# Clear out COMECIM nodes 
find /var/rvb/network -type f -iname "*RNC*" -exec rm {} \;
find /var/rvb/network -type f -iname "*RBS*" -exec rm {} \;
find /var/rvb/network -type f -iname "*SGSN*" -exec rm {} \;
find /var/rvb/network -type f -iname "*DG2*" -exec rm {} \;
find /var/rvb/network -type f -iname "*mgw*" -exec rm {} \;

# Parse the network
/opt/ericsson/enmutils/bin/node_populator parse rvb-network /var/rvb/network

# Get the current status of the netsim simulations
for SEGMENT in ${NETWORK[@]}; do
    NETSIM_HOST=$(echo $SEGMENT | cut -f1 -d:)
    SIMS=$(echo $SEGMENT | cut -f2 -d:)

    for SIM in $(echo $SIMS | sed "s/,/ /g"); do
        echo "Current Status of $NETSIM_HOST $SIM"
        /opt/ericsson/enmutils/bin/netsim activities $NETSIM_HOST $SIM
    done
done
