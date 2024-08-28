#!/bin/bash

while getopts h: option
do
 case "${option}"
 in
 h) HOUR=${OPTARG};;
 esac
done

DATEDIR=$(date +%d%m%y)
GREPDATE=$(date +%d-%m-%y)

CPYDIR=/ericsson/enm/dumps/FMKPI
DDCDIR=/var/ericsson/ddc_data/

[ ! -d ${CPYDIR} ] && mkdir -p ${CPYDIR} && chmod 777 ${CPYDIR}

touch ${CPYDIR}/mbeans.txt

H=${HOUR}

[ ${HOUR} -ge 0 ] && [ ${HOUR} -le 9 ] && HOUR=`echo "0${HOUR}"`

for file in `ls ${DDCDIR}/svc-*-ms*fm_TOR/${DATEDIR}/instr.txt`;
do
  sed -n "/${GREPDATE} ${HOUR}:/p" $file | grep -e "type=MediationInstrumentatedBean" -e "type=SnmpEngineStatisticsExt" -e "type=AxeEngineStatisticsExt" >> ${CPYDIR}/mbeans.txt
done

header="\n %7s %10s %10s %10s %12s %10s\n"
format=" %4d:%2d %10d %10d %10d %12d %10.2f\n"

printf "$header" "TIME" "MSFM" "MSSNMPFM" "MSAPGFM" "PER_MIN" "PER_SECOND"
printf "=================================================================\n"

PER_HOUR=0

for MIN in {0..58}
do
   MIN_START=$MIN
   MIN_STOP=`expr $MIN_START + 1`

   [ ${MIN_START} -ge 0 ] && [ ${MIN_START} -le 9 ] && MIN_START=`echo "0${MIN_START}"`
   [ ${MIN_STOP} -ge 0 ] && [ ${MIN_STOP} -le 9 ] && MIN_STOP=`echo "0${MIN_STOP}"`


   #Total alarms from MSFM

#31-08-18 00:00:07.542 CFG-svc-3-msfm-com.ericsson.oss.mediation.alarm.instrumentation.impl.cpp-alarm-event-resource-adaptor:type=MediationInstrumentatedBean failedAlarmCountSendFromMediation nodeUnderNodeSuspendedState nodesUnderHeartBeatFailure nodesUnderSupervision totalAlarmCountSendFromMediation

   BEFORE=`grep -e "${GREPDATE} ${HOUR}:${MIN_START}:" ${CPYDIR}/mbeans.txt | grep "type=MediationInstrumentatedBean" | awk 'BEGIN{sum=0;count=0} {sum+=$NF;++count} END {printf "%d\n", sum}'`
   AFTER=`grep -e "${GREPDATE} ${HOUR}:${MIN_STOP}:" ${CPYDIR}/mbeans.txt | grep "type=MediationInstrumentatedBean" | awk 'BEGIN{sum=0;count=0} {sum+=$NF;++count} END {printf "%d\n", sum}'`

   MSFM=`echo "${AFTER}-${BEFORE}" | bc -l`


   #Total alarms from MSSNMPFM

#31-08-18 00:00:06.821 CFG-svc-5-mssnmpfm-com.ericsson.oss.mediation.fm.service.instrumentation.snmp-fm-engine:type=SnmpEngineStatisticsExt alarmForwardedFailures alarmProcessingDiscarded alarmProcessingInvalidRecordType alarmProcessingLossOfTrap alarmProcessingPing alarmProcessingSuccess alarmsForwarded alarmsProcessingFailures alarmsProcessingNotSupported alarmsReceived forwardedProcessedAlarmFailures forwardedProcessedSyncAlarm forwardedProcessedSyncAlarmFailures multiEventFailed multiEventProcessed multiEventReordered syncAlarmCommand syncAlarmProcessingSuccess syncAlarmsProcessingFailures syncAlarmsReceived syncProcessingNotSupportedAlarms


   BEFORE=`grep -e "${GREPDATE} ${HOUR}:${MIN_START}:" ${CPYDIR}/mbeans.txt | grep "type=SnmpEngineStatisticsExt" | awk 'BEGIN{sum=0;count=0} {sum+=$10;++count} END {printf "%d\n", sum}'`
   AFTER=`grep -e "${GREPDATE} ${HOUR}:${MIN_STOP}:" ${CPYDIR}/mbeans.txt | grep "type=SnmpEngineStatisticsExt" | awk 'BEGIN{sum=0;count=0} {sum+=$10;++count} END {printf "%d\n", sum}'`

   MSSNMPFM=`echo "${AFTER}-${BEFORE}" | bc -l`

   #Total alarms from MSAPGFM

#30-08-18 16:50:14.970 CFG-svc-7-msapgfm-com.ericsson.oss.mediation.fm.axe.engine.instrumentation.axe-fm-mediation-engine:type=AxeEngineStatisticsExt alarmsProcessingFailure alarmsProcessingSuccess axeAlarmsDiscarded axeAlarmsReceived heartBeatPingsReceived numOfHBFailureNodes numOfOutOfSyncNodes numOfSupervisedNodes processedAlarmsForwarded processedAlarmsForwardedFailure processedSyncAlarmsForwarded processedSyncAlarmsForwardedFailures spontAlarmsReceived syncAlarmsReceived unKnownAlarmTypesReceived

   BEFORE=`grep -e "${GREPDATE} ${HOUR}:${MIN_START}:" ${CPYDIR}/mbeans.txt | grep "type=AxeEngineStatisticsExt" | awk 'BEGIN{sum=0;sum2=0; count=0} {sum+=$12;sum2+=$14;++count} END {printf "%d\n", sum+sum2}'`
   AFTER=`grep -e "${GREPDATE} ${HOUR}:${MIN_STOP}:" ${CPYDIR}/mbeans.txt | grep "type=AxeEngineStatisticsExt" | awk 'BEGIN{sum=0;sum2=0;count=0} {sum+=$12;sum2+=$14;++count} END {printf "%d\n", sum+sum2}'`

   MSAPGFM=`echo "${AFTER}-${BEFORE}" | bc -l`

   #Calculate total processed

   TOTAL_TIME_MIN=`echo "${MSFM}+${MSSNMPFM}+${MSAPGFM}" | bc -l`
   TOTAL_TIME_SEC=`echo "scale=2;${TOTAL_TIME_MIN}/60" | bc -l`

   if [ ${TOTAL_TIME_MIN} -gt 0 ]
   then
       printf "$format" ${H} ${MIN} ${MSFM} ${MSSNMPFM} ${MSAPGFM} ${TOTAL_TIME_MIN} ${TOTAL_TIME_SEC}
       PER_HOUR=`echo "${TOTAL_TIME_MIN}+${PER_HOUR}" | bc -l`
   fi

done

printf "=================================================================\n"
echo "Total alarms mediated for the hour ${HOUR} is: ${PER_HOUR}"
printf "=================================================================\n"

[ -f ${CPYDIR}/mbeans.txt ] && rm -rf ${CPYDIR}/mbeans.txt