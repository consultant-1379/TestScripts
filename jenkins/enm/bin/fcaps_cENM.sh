#!/bin/bash
###############################################################
## Scrtipt: FCAPS load check                                 ##
## Author : rajesh.chiluveru.ext@ericsson.com                ##
## Last Modified: 27-June-2022                               ##
###############################################################
echo -e "\e[0;34m Version: 7.3 \e[0m"
cENM_id=`/usr/local/bin/kubectl --kubeconfig /root/.kube/config get ingress --all-namespaces | egrep ui|awk '{print $1}'`
rv_dailychecks_tmp_file="/ericsson/enm/dumps/.rv_dailychecks_tmp_file.log"
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"

if [ $# -eq 1 ]
then
dt1=`echo $1`
elif [ $# -eq 0 ]
then
dt1=`date "+%Y-%m-%d"`
else
   echo "  Syntax ERROR .. !!! "
   echo -e "\e[0;32m  Script Help - Run script as follows with/without date arugument \e[0m ** Supports only for cENM **"
   echo -e "\e[0;32m  ./fcaps_cENM.sh <date in yyyy-mm-dd> \e[0m"
   echo "1). For *cENM* Ensure kube config file is present on WORKLOAD VM."| sed "s/^/\t/g"
   echo
   exit 1
fi

cmimport_sts(){
echo -e "\e[0;32mCMIMPORT Jobs Statistics for given date :\e[0m $dt1"
echo -e "\e[0;32m---------------------------------\e[0m"
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d importdb -c "select substring(username from 1 for 11) as profile,status,count(*) as Count from job where to_char(time_start, 'yyyy-mm-dd')='$dt1' group by substring(username from 1 for 11),status;" > /tmp/cmimport_sts.txt
cat /tmp/cmimport_sts.txt|egrep 'profile|CMIMPORT|--'
echo
echo -e "\e[0;33m ** Total CMIMPORT Jobs for the date ** :\e[0m `awk -F"|" '{ sum += $3 } END { print sum }' /tmp/cmimport_sts.txt`/out of 508 "
echo
}

cmexport_sts(){
echo -e "\e[0;32mCMEXPORT Jobs Statistics for given date :\e[0m $dt1"
echo -e "\e[0;32m---------------------------------\e[0m"
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d exportds -c "select substring(split_part(split_part(jobparameters, 'jobName =', 2), 'serverId', 1) from 1 for 12) as profile,exitstatus as status,count(*) as count from job_execution where to_char(starttime, 'yyyy-mm-dd')='$dt1' and jobparameters like '%ZIP%' group by substring(split_part(split_part(jobparameters, 'jobName =', 2), 'serverId', 1) from 1 for 12),exitstatus;" > /tmp/cmexport_sts.txt
cat /tmp/cmexport_sts.txt|egrep 'profile|CMEXPORT|--'
echo
echo -e "\e[0;33m ** Total CMEXPORT Jobs for the date ** :\e[0m `awk -F"|" '{ sum += $3 } END { print sum }' /tmp/cmexport_sts.txt`/out of 1000 "
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d exportds -c "select split_part(split_part(jobparameters, 'exportType =', 2), 'enumTranslate', 1) as type,exitstatus as status,count(*) as count from job_execution where to_char(starttime, 'yyyy-mm-dd')='$dt1' and jobparameters like '%ZIP%' group by split_part(split_part(jobparameters, 'exportType =', 2), 'enumTranslate', 1),exitstatus;" > /tmp/cmexport_sts.txt2
echo
cat /tmp/cmexport_sts.txt2|egrep 'type|[0-9]|--'|grep -v row
echo
}

pm_uplink_sts(){
echo -e "\e[0;32mPM_52 Uplink Statistics for last 15 minutes :\e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d flsdb -c "select to_char(sample_time, 'yyyy-mm-dd hh24:mi'),count(*) from ulsa_info where file_location like '%ULSA_SAMPLE' group by to_char(sample_time, 'yyyy-mm-dd hh24:mi') order by to_char(sample_time, 'yyyy-mm-dd hh24:mi') desc LIMIT 15;"
}

pm79_uplink_sts(){
echo -e "\e[0;32mPM_79 Uplink stats between 13 & 18hrs :\e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
echo "+++++++++++++++++++++++"
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d flsdb -c "select to_char(sample_time, 'yyyy-mm-dd hh24:mi'),count(*) from ulsa_info where file_location not like '%ULSA_SAMPLE' group by to_char(sample_time, 'yyyy-mm-dd hh24:mi') order by to_char(sample_time, 'yyyy-mm-dd hh24:mi') desc LIMIT 15;"
}

nhmkpi_sts(){
echo -e "\e[0;32mNHM KPI generated per ROP :\e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d kpiservdb -c "select to_timestamp(cast(substring(cast(rop as text) from 1 for 10) as integer)),count(*) from kpi_data group by to_timestamp(cast(substring(cast(rop as text) from 1 for 10) as integer)) order by to_timestamp(cast(substring(cast(rop as text) from 1 for 10) as integer));"
}

fm_node_sts(){
echo -e "\e[0;32mFM Node Status: \e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
rm -f /tmp/rajesh.txt
kubectl -n ${cENM_id} cp `kubectl get pods -n ${cENM_id}|grep mssnmpfm|head -1|awk '{print $1}'`:ericsson/tor/data/fm/fmrouterpolicy/data/FmRouterPolicyMappings.txt /tmp/rajesh.txt
strings /tmp/rajesh.txt | grep -oP '.*mediationservice' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
echo
kubectl get pods -n ${cENM_id}|egrep 'msfm|mssnmpfm'
echo
}

pmnbi_sts(){
echo -e "\e[0;32mPM NBI Status for last 5 ROPs :\e[0m"
echo -e "\e[0;32m---------------------------------\e[0m"
grep "PM_26 NBI File Transfer Results" /var/log/enmutils/daemon/pm_26.log | tail -5
echo
}

fm_alarm_count(){
        echo
        echo -e "\e[0;32mFM open Alarm Count: \e[0m"
        echo -e "\e[0;32m--------------------------\e[0m"
        ${CLI_APP} 'alarm get * --count' | awk '{print $NF}' | sed "s/^/\t/g"
}

fm_enm_alarms(){
        echo
        echo -e "\e[0;32mSummary of ENM Management System FM Alarm Specific Problems reported for today: \e[0m"
        echo -e "\e[0;32m-------------------------------------------------------------------------------\e[0m"
        ${CLI_APP} 'alarm get ENM' |grep "$(date +%Y-%m-%d)" > ${rv_dailychecks_tmp_file}
        for i in `awk '{print $1}' ${rv_dailychecks_tmp_file} | uniq`;
        do
                echo $i | sed "s/^/\t/g";
                grep $i ${rv_dailychecks_tmp_file} | awk -F "\t" {'print $3}' | sort | uniq -c| sort -nrk1 | sed "s/^/\t/g";
        done
        echo ""
        echo -e "\e[0;35mFor full details run: \e[0m cli_app 'alarm get ENM' |grep $(date +%Y-%m-%d) " | sed "s/^/\t/g"
        truncate -s 0 ${rv_dailychecks_tmp_file}
}
cmimport_sts
cmexport_sts
fm_node_sts
fm_alarm_count
fm_enm_alarms
pm_uplink_sts
pm79_uplink_sts
pmnbi_sts
/root/rvb/bin/Quick_PM_data_Check.sh
nhmkpi_sts
/opt/ericsson/enmutils/bin/network status --groups
