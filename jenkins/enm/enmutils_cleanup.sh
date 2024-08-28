#!/bin/bash

# Stop any workload profiles that might be running
if [ -f /opt/ericsson/enmutils/bin/workload ]; then
        /opt/ericsson/enmutils/bin/workload stop all

	# sleep for ten minutes so we can give the profiles time to shutdown
	sleep 600
fi


if [ -f /opt/ericsson/enmutils/bin/persistence ]; then
        /opt/ericsson/enmutils/bin/persistence clear force
fi

# Stop the ENM utils DB if it is running and remove the DB file
pkill -f enmutils-db
pkill -f daemon.py
rm -rf /var/db/enmutils/*
rm -rf /tmp/enmutils/daemon/*.pid
rm -rf /var/db/enmutils/enmutils.db

# Remove the ENM utils RPMs
rpm -ev --allmatches ERICdeploymentvalidation_CXP9032314
rpm -ev --allmatches ERICtorutilitiesinternal_CXP9030579
rpm -ev --allmatches ERICtorutilities_CXP9030570

exit 0
