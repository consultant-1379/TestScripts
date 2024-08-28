#!/bin/bash
mkdir -p /var/rvb/network
rm -f /var/rvb/network/*

LATEST_SUPPORTED_ENMUTILS_VERSION=`cat /root/rvb/enmutils_stable.txt`

if [ $1 == "330" ]; then
    #If more sims needed ieatnetsimv6041-02 is also available
    NETWORK=("ieatnetsimv5030-01.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-LTE02,LTEG1124-limx160-5K-FDD-LTE03,LTEF1108-limx160-5K-FDD-LTE04")
    #NETWORK=("ieatnetsimv5030-01.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-LTE02,LTEG1124-limx160-5K-FDD-LTE03,LTEF1108-limx160-5K-FDD-LTE04",
     #        "ieatnetsimv5030-02.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-02-LTE02,LTEG1124-limx160-5K-FDD-02-LTE03,LTEF1108-limx160-5K-FDD-02-LTE04,LTEE1239x160-5K-FDD-02-LTE05,LTEE163-V3x160-5K-FDD-02-LTE06",
     #        "ieatnetsimv5030-03.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-02-LTE02,LTEG1124-limx160-5K-FDD-02-LTE03,LTEF1108-limx160-5K-FDD-02-LTE04,LTEE1239x160-5K-FDD-02-LTE05,LTEE163-V3x160-5K-FDD-02-LTE06",
     #        "ieatnetsimv5030-04.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-02-LTE02,LTEG1124-limx160-5K-FDD-02-LTE03,LTEF1108-limx160-5K-FDD-02-LTE04,LTEE1239x160-5K-FDD-02-LTE05,LTEE163-V3x160-5K-FDD-02-LTE06",
     #        "ieatnetsimv5030-05.athtem.eei.ericsson.se:LTEG1240-limx160-5K-FDD-02-LTE02,LTEG1124-limx160-5K-FDD-02-LTE03,LTEF1108-limx160-5K-FDD-02-LTE04,LTEE1239x160-5K-FDD-02-LTE05,LTEE163-V3x160-5K-FDD-02-LTE06")



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

# Parse the network
/opt/ericsson/enmutils/bin/node_populator parse rvb-network /var/rvb/network