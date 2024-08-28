#!/bin/bash

while getopts t:h:s:e:d:n: option
do
 case "${option}"
 in
 h) HOUR=${OPTARG};;
 t) TYPE=${OPTARG};;
 s) MIN_START=${OPTARG};;
 e) MIN_STOP=$OPTARG;;
 d) USERDIR=$OPTARG;;
 n) NODE=$OPTARG;;
 esac
done

DATE=$(date +%F)


[ ! -d /ericsson/enm/dumps/SHMInv ] && mkdir -p /ericsson/enm/dumps/SHMInv && chmod 777 /ericsson/enm/dumps/SHMInv

DATEDIR=$(date +%d%h%H%M)

if [ 'NEW' == ${TYPE} ]
then
   echo "Create new DIR"

   [ ! -d /ericsson/enm/dumps/SHMInv/${DATEDIR} ] && mkdir -p /ericsson/enm/dumps/SHMInv/${DATEDIR} && chmod 777 /ericsson/enm/dumps/SHMInv/${DATEDIR}

   INVDIR=/ericsson/enm/dumps/SHMInv/${DATEDIR}
   for ip in `awk '{print $2}' /etc/hosts | grep "mscm$"`
   do 
      echo "============ ${ip} ==========="
      ssh -i /root/.ssh/vm_private_key cloud-user@`echo $ip` "cp -p /ericsson/3pp/jboss/standalone/log/server.log ${INVDIR}/${ip}.server.log"
   done
elif [ 'CHECK' == ${TYPE} ]
then
   echo "Use user directory"
   INVDIR=/ericsson/enm/dumps/SHMInv/${USERDIR}
else
   echo "******************************************************************************"
   echo "Correct the Type condtion given.."
   echo "Help to Check previous data: sh findSyncTime_imp.sh -t CHECK -h <Hour> -s <MIN Start> -e <Minutes END> -n <no_of_nodes> -d <DirName_of_previous_run>"
   echo "Help to 1st Run: sh findSyncTime_imp.sh -t NEW -h <Hour> -s <MIN Start> -e <Minutes END> -n <no_of_nodes>"
   echo "******************************************************************************"
   exit 1
fi

echo "======================================================================================="
echo "Files stored: ${INVDIR}"

touch ${INVDIR}/str.txt

for file in `ls ${INVDIR}/*mscm.server.log`;
do
   sed -n "/${DATE} ${HOUR}:${MIN_START}/,/${DATE} ${HOUR}:${MIN_STOP}/!d;/PICIHandler onEvent invoked.../p;/Persisting Inventory with :/p;/Exiting PICIDPSHandler .../p" ${file} >> ${INVDIR}/str.txt
done


echo "--------- PICIHandler onEvent invoked ---------"
STR_START=$(grep "PICIHandler onEvent invoked..." ${INVDIR}/str.txt | sort | sed -n -e 1p)
echo "STR_START: ${STR_START}"

echo "--------- Persisting Inventory with ---------"
DPS_PRINT=$(grep "Persisting Inventory with :" ${INVDIR}/str.txt | sort | sed -n -e 1p -e ${NODE}p)
echo "DPS_PRINT: ${DPS_PRINT}"


echo "--------- Exiting PICIDPSHandler ---------"
STR_STOP=$(grep "Exiting PICIDPSHandler ..." ${INVDIR}/str.txt | sort | sed -n -e ${NODE}p)
echo "STR_STOP: ${STR_STOP}"

STR_START=$(echo $STR_START |awk '{print $2}')
STR_STOP=$(echo $STR_STOP |awk '{print $2}')

END=$(echo "${STR_STOP}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }');START=$(echo "${STR_START}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'); echo "Start: $START, End: $END"; TT=$(echo "scale=2;($END-$START) / 60"| bc -l)

echo "Total time to perform Inv sync for ${NODE} node is: ${TT} minutes"

##CLEANUP

[ -f ${INVDIR}/str.txt ] && rm -rf ${INVDIR}/str.txt

echo "======================================================================================="
