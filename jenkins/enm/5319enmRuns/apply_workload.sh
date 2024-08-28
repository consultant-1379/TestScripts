#!/bin/bash

# Check the state of the cluster
/opt/ericsson/enminst/bin/enm_healthcheck.sh --action vcs_service_group_healthcheck

# Start FM profile(s) and enable supervision
set -ex
/opt/ericsson/enmutils/bin/workload start fm_setup,fm_01
sleep 120
/opt/ericsson/enmutils/bin/cli_app "fmedit set * FmAlarmSupervision alarmSupervisionState=true"

# Start the PM profile(s) and enable supervision

/opt/ericsson/enmutils/bin/workload start pm_02
sleep 120
/opt/ericsson/enmutils/bin/cli_app "cmedit set * PmFunction.(PmFunctionId==1) pmEnabled=true"


# Sleep for 15 minute to allow all the load to start up and then trigger a sync of all the nodes
sleep 900
/opt/ericsson/enmutils/bin/cli_app "cmedit set * CmNodeHeartbeatSupervision active=true"


# Start the CM profiles
#/opt/ericsson/enmutils/bin/workload start cm_export_03

#Check the network sync status
/opt/ericsson/enmutils/bin/network status --groups