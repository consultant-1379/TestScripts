#!/bin/bash

### This script will perform SHM inventory sync
### for 1000 nodes or 320 nodes based on NRM
### Script will take only SHM synchronized nodes as per TORRV-7472

CLI_APP=/opt/ericsson/enmutils/bin/cli_app
SYNC=0
UNSYNC=0
LOOP=0
LOOPLIMIT=15
START=0
END=0
LIMIT=0
ABOVE5K=1000
FIVEKNODES=480

source ~/.bashrc

NE_COUNT=`${CLI_APP} "cmedit get * InventoryFunction.(syncStatus==SYNCHRONIZED) -ne=ERBS -cn" | grep -v found | awk '{print $1}'`

if [ "${NE_COUNT}" -eq "${NE_COUNT}" ] 2>/dev/null
then
   if [ "${NE_COUNT}" -le 0 ]
   then
      echo "No nodes retrived to perform Inventory Sync. Exiting...."
      exit 1
   fi
else
    echo "Could not able to retrieve the NE COUNT. Issue could be with CLI. Result retrived is : ${NE_COUNT}"
    echo "Exiting..."
    exit 1
fi

echo "Total Number of ERBS nodes are: ${NE_COUNT}"

if [ "${NE_COUNT}" -ge "${ABOVE5K}" ]
then
   LIMIT=1000
elif [ "${NE_COUNT}" -le "${FIVEKNODES}" ]
then
   LIMIT=320
else
   LIMIT=${NE_COUNT}
fi

echo "Number of nodes to perform Inv Sync is: ${LIMIT}"

NE_LIST=`${CLI_APP} "cmedit get * InventoryFunction.(syncStatus==SYNCHRONIZED) -ne=ERBS" | grep FDN | cut -d'=' -f2 | cut -d',' -f1 | sort -R | tail -${LIMIT}| sed 's/$/;/g'`

SEARCH_STRING=(`printf "%s" ${NE_LIST} | sed 's/;/|/g' | sed 's/.$//'`)

function TOGGLE_SHM_SUPERVISION() {

   node=`echo ${NE_LIST} | sed 's/;/;\n/g'`
   node=`printf "%s" ${node%?}`

   echo "DISABLE_SHM_SUPERVISION for ${LIMIT} at $(date)"
   NO_OF_DISABLED_SUP=$(${CLI_APP} "cmedit set --node ${node} InventorySupervision active=false" | egrep "instance" | awk '{print $1}')
   echo "Total number of nodes ${LIMIT}, and Number of nodes disabled SHM supervision is: ${NO_OF_DISABLED_SUP}"
   echo "Finished DISABLE_SHM_SUPERVISION at $(date)"

   echo "Sleep for 120 seconds to make sure all nodes shm supervision is disabled"
   sleep 120

   GET_NUM_UNSYNC_NODES

   echo "ENABLE_SHM_SUPERVISION for ${LIMIT} nodes at $(date)"

   START=$(date +%s)
   NO_OF_ENABLED_SUP=$(${CLI_APP} "cmedit set --node ${node} InventorySupervision active=true" | egrep "instance" | awk '{print $1}')
   echo "Total number of nodes ${LIMIT}, and Number of nodes enabled SHM supervision is: ${NO_OF_ENABLED_SUP}"
   END=$(date +%s);

   echo "Finished ENABLE_SHM_SUPERVISION for ${LIMIT} nodes at $(date)"

}

function GET_NUM_UNSYNC_NODES() {
   echo " Checking UNSYNC"
   UNSYNC=$(${CLI_APP} 'cmedit get * InventoryFunction.syncStatus==UNSYNCHRONIZED -ne=ERBS' | egrep -c "${SEARCH_STRING}")
   echo "Number unsynch is ${UNSYNC}"
}

function GET_NUM_SYNC_NODES() {
   echo " Checking SYNC"
   SYNC=$(${CLI_APP} 'cmedit get * InventoryFunction.syncStatus==SYNCHRONIZED -ne=ERBS' | egrep -c "${SEARCH_STRING}")
}

function test_KPI(){
   date
   echo "======================================================================================"
   echo "Start of SHM STKPI Inventory Sync for ${LIMIT} nodes"
   echo "**************************************************************************************"

   if [ "${LIMIT}" -gt 0 ]
   then
      TOGGLE_SHM_SUPERVISION
   else
      echo "No nodes fetched to perform Inv Sync, so exciting.."
      exit 1
   fi

   echo "*****Waiting for results****"
   while [ "${SYNC}" -lt "${LIMIT}" ] && [ "${LOOP}" -lt ${LOOPLIMIT} ]
   do
      let LOOP=LOOP+1
      GET_NUM_SYNC_NODES
      INTERVAL=$(date +%s);
      IT=$(date -u -d "0 ${INTERVAL} seconds - ${START} seconds" +"%H:%M:%S")
      echo "Interval time taken for ${SYNC} nodes out of ${LIMIT} NODES is ${IT} "

      if [ "${SYNC}" -lt "${LIMIT}" ] && [ "${LOOP}" -lt ${LOOPLIMIT} ]
      then
         echo "Waiting for 20 seconds....."
         sleep 20
      fi
   done

   echo "*******************************************************************************************************************"
   echo "SHM INVENTORY SYNC HAS BEEN SUCCESSFUL FOR ${SYNC} nodes out of ${LIMIT} NODES in ${IT} on $(date +"%Y-%m-%dT%T_%a")"
   echo "==================================================================================================================="

   if [ "${SYNC}" -lt "${LIMIT}" ]
   then
      echo "Print SHM UnSync nodes after the number of retries are..."
      ${CLI_APP} "cmedit get * InventoryFunction.syncStatus==UNSYNCHRONIZED -ne=ERBS" | egrep "${SEARCH_STRING}"
   fi

   date
}

echo "In main"

test_KPI

echo "Finished"
echo
echo