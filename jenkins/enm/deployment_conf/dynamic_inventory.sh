#!/bin/bash

# This script presents the deployment conf files in a json format to allow them to be used as an ansible inventory

BASEDIR=`dirname $0`
DEPLOYMENT_CONF_FILES=($BASEDIR/5*.conf)

echo "{"
for CONF_FILE in "${DEPLOYMENT_CONF_FILES[@]}"
do
    source $CONF_FILE
    NETSIM_LIST=""
    for LINE in "${NETWORK[@]}"
    do
        NETSIM=`echo $LINE | cut -d: -f1`
        NETSIM_LIST="$NETSIM_LIST \"$NETSIM\","
    done
    NETSIM_LIST=$(echo $NETSIM_LIST | sed -e 's/,$//')
    echo "\"${CLUSTER}_netsims\" : [ $NETSIM_LIST ],"
done
echo "}"
