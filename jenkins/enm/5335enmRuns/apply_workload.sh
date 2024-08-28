#!/bin/bash

# Check the state of the cluster
/opt/ericsson/enmutils/bin/enm_check


# Start FM profiles and enable the supervision
set -ex
/opt/ericsson/enmutils/bin/cli_app "fmedit set * FmAlarmSupervision alarmSupervisionState=true"
sleep 120

# Remove these two files as they need Radio and SGSN-MME NODES
rm -f /opt/ericsson/enmutils/.env/lib/python2.7/site-packages/enmutils_int/lib/workload/cmexport_07.py /opt/ericsson/enmutils/.env/lib/python2.7/site-packages/enmutils_int/lib/workload/cmexport_12.py



# Sleep for 30 minute to allow all the load to start up and then trigger a sync of all the nodes

/opt/ericsson/enmutils/bin/cli_app "cmedit set * CmNodeHeartbeatSupervision active=true"


sleep 900

/opt/ericsson/enmutils/bin/workload start all

