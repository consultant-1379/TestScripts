#!/bin/bash

COMMAND="/opt/ericsson/enminst/bin/enm_healthcheck.sh -v"
SUCCESS_STATEMENT="Successfully Completed ENM System Healthcheck"

LOGFILE="enm_healthcheck.log"
cp /dev/null $LOGFILE

echo "Running command: $COMMAND"
$COMMAND | /usr/bin/tee -a $LOGFILE
[[ $? != 0 ]] && { echo "Problem with execution of ENM Healthcheck command ...exiting"; exit 1; }

egrep "$SUCCESS_STATEMENT" $LOGFILE
[[ $? != 0 ]] && { echo "ENM Healthcheck NOT Passed - Remedial action needed"; exit 1; } || { echo "ENM Healthcheck Passed - OK to proceed"; exit 0; }

