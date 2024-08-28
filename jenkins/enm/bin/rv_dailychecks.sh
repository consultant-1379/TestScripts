#!/bin/bash

echo ""
TITLE="Script to perform a series of application & system checks on an ENM system."

displayHelpMessage() {
  echo
  echo "$TITLE"
  echo "Usage: $0 {-h | -w}"
  echo ""
  echo "where"
  echo " -h        Help - Displays this message"
  echo " -w        Weekend - Run a shorter series of checks for Weekend Monitoring"
  echo " Also note the following pre-requisities:" | sed "s/^/\t\t/g"
  echo "========================================" | sed "s/^/\t\t/g"
  echo "Ensure that passwordless access is setup between LMS and netsim VMs and also between LMS and OMBS server" | sed "s/^/\t\t/g"
  echo "i.e. Copy ~/.ssh/id_rsa.pub on LMS into ~/.ssh/authorized_keys file of OMBS server" | sed "s/^/\t\t/g"
  echo "Ensure ERICtorutilitiesinternal rpm is installed on the LMS"
  echo "Ensure directories physical_rv_dailychecks/, flsdb_pm_rop_stats/ &  rv_dailychecks/ exist under /ericsson/enm/dumps/ on WLVM for cloud/vio envs"
  echo "Cloud: Ensure password-less connection is setup between WLVM and VMS for VMS Overview & HC status."
}

export PGPASSWORD=P0stgreSQL11
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
VCS="/opt/ericsson/enminst/bin/vcs.bsh"
NETWORK="/opt/ericsson/enmutils/bin/network"
DATE=$(date +%Y%m%d)
Date2=$(date +%Y-%m)
DDP_DATE=$(date +%d%m%y)
ENM_HEALTHCHECK='/opt/ericsson/enminst/bin/enm_healthcheck.sh'
fmx=$(cat /etc/hosts | grep fmx | awk '{print $2}' | head -1)
sed="/bin/sed"
sshvm="/root/rvb/bin/ssh_to_vm_and_su_root.exp"
hostname=$(hostname)
lvs="/sbin/lvs"
date_stamp=$(date +%Y%m%d)
start_hour=$(date -d '2 hour ago' +%H)
end_hour=$(date -d '1 hour ago' +%H)
if [ -e /usr/openv/netbackup/bp.conf ]; then
  ombs_server=$(cat /usr/openv/netbackup/bp.conf | grep SERVER | egrep "bkup|bkp" | awk '{print $NF}' | head -1)
fi
if [ -e /opt/ericsson/itpf/bur/log/brs/brs.log ]; then
  ombs_keyword=$(cat /opt/ericsson/itpf/bur/log/brs/brs.log.1 /opt/ericsson/itpf/bur/log/brs/brs.log | grep -i "Started BRS CLI with args: backup_files" | tail -1 | awk -F "keyword " '{print $2}' | awk '{print $1}')
fi

env_type() {
  #Determine if env is cloud or physical based on existence of /var/ericsson/ddc_data/config/ddp.txt on LMS (physical). Otherwise this is considered a cloud env.
  #Also set environment variables required.
  echo
  echo -e "\e[0;32mChecking environment type:\e[0m"
  echo -e "\e[0;32m==========================\e[0m"
  env_type=$([ -e /var/ericsson/ddc_data/config/ddp.txt ] && echo "physical" || echo "cloud")
  echo "This is a ${env_type} environment." | sed "s/^/\t/g"

  # Set common variables & setup files required
  WORKLOAD_VM=$(grep wlvm /root/.bashrc | grep -oP "ieat.*[0-9]{2,4}[a-z]?")
  #stkpi_erbs=`cat /etc/cron.d/stkpi_CM_Synch_01 | head -1 | awk -F "_" '{print $NF}'`
  #stkpi_netsim=`grep -ril ${stkpi_erbs} /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP ieat.*[0-9][0-9]`
  #stkpi_sim=`grep ${stkpi_erbs} -ri /opt/ericsson/enmutils/etc/nodes/| grep -v failed | awk -F ", " '{print $23}'`
  rv_dailychecks_tmp_file="/ericsson/enm/dumps/rv_dailychecks_tmp_file.log"
  UNSYNCHED='/opt/ericsson/enmutils/bin/cli_app "cmedit get * CmFunction.syncStatus!="SYNCHRONIZED" -t"'
  user_mgr="/opt/ericsson/enmutils/bin/user_mgr"
  VCC_DATE1=$(date +%b" "%d)
  VCC_DATE2=$(date | awk '{print $2,"",$3}')
  workload=/opt/ericsson/enmutils/bin/workload

  [ ! -d /ericsson/enm/dumps/rv_dailychecks/ ] && mkdir -p /ericsson/enm/dumps/rv_dailychecks/ && chmod 777 /ericsson/enm/dumps/rv_dailychecks/

  touch ${rv_dailychecks_tmp_file}
  truncate -s 0 ${rv_dailychecks_tmp_file}

  if [ ${env_type} == "cloud" ]; then
    keypair="/var/tmp/enm_keypair.pem"
    consul_members='/var/tmp/consul_members.txt'

    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "exec sudo -i" consul members list >${consul_members}
    #Copy pem file to EMP VM:
    scp -i ${keypair} ${keypair} cloud-user@$EMP:/var/tmp &>/dev/null

    #Cloud Specific Parameters to be setup:
    vnflaf_internal_ip=$(grep vnflaf-services ${consul_members} | awk '{print $2}' | awk -F ":" '{print $1}')
    vnflaf_external_ip=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${vnflaf_internal_ip}" "exec sudo -i" ifconfig eth1 | grep -w inet | awk '{print $2}')

    scp -i ${keypair} ${keypair} cloud-user@${vnflaf_external_ip}:/var/tmp &>/dev/null

    #In case env has been upgraded we need to remove the old ssh key each time and add in the new/existing one.
    ${sed} -i '/${vnflaf_external_ip}/d' /root/.ssh/known_hosts

    esmon_ip=$(grep esmon ${consul_members} | awk '{print $2}' | awk -F ":" '{print $1}')
    ddp_server=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${esmon_ip}" "exec sudo -i" grep ddcDataUpload /var/log/cron | tail -1 | grep -oP ddpenm"\d")
    dps_persistence_provider=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${esmon_ip}" "exec sudo -i" egrep "dps_persistence_provider" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}' | tr -d '\r')
    neo_instance=$(grep neo4j-0 /var/tmp/consul_members.txt | awk '{print $2}' | awk -F ":" '{print $1}')
    #******neo4j_leader=`ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${neo_instance}" "exec sudo -i" egrep "neo4j_cluster" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}'`
    #******neo4j_cluster_type=`ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${neo_instance}" "exec sudo -i" egrep "neo4j_cluster" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}'`
    CLUSTER=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@${esmon_ip}" "exec sudo -i" grep ddcDataUpload /var/log/cron | tail -1 | grep -oP "\-s.*" | awk '{print $2}' | grep -oP ".*[0-9]{3}")
    elasticsearch_ip=$(grep elasticsearch ${consul_members} | awk '{print $2}' | awk -F ":" '{print $1}')
    svc_CM_vip_ipaddress=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "consul kv get enm/deprecated/global_properties/svc_CM_vip_ipaddress")
    svc_CM_vip_ipv6address=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "consul kv get enm/deprecated/global_properties/svc_CM_vip_ipv6address")
    solr_hostname=$(grep -w solr /var/tmp/consul_members.txt | awk '{print $1}')

    vms_ip_vio_mgt=$(curl -s "https://atvdit.athtem.eei.ericsson.se/api/documents/?q=name=vio_5625&fields=content(parameters(vms_ip_vio_mgt)" | grep vms_ip_vio_mgt | awk -F "\"" '{print $8}') >/dev/null

    if [ -e /etc/cron.d/stkpi_CM_Synch_01 ]; then
      stkpi_erbs=$(cat /etc/cron.d/stkpi_CM_Synch_01 | head -1 | awk -F "_" '{print $NF}')
      stkpi_netsim=$(grep -ril ${stkpi_erbs} /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP 'ieatnetsimv[0-9]{4}-[0-9]{2}')
      stkpi_sim=$(grep ${stkpi_erbs} -ri /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP "html.*ieat" | awk -F ", " '{print $2}')
    fi

    echo

  else
    ddp_server=$(grep ddcDataUpload /var/log/cron | tail -1 | grep -oP ddpenm"\d")
    dps_persistence_provider=$(egrep "dps_persistence_provider" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}')
    CLUSTER=$(grep ddcDataUpload /var/log/cron | tail -1 | grep -oP "\-s.*" | awk '{print $2}' | grep -oP ".*[0-9]{3}")
    neo_instance=$(/opt/ericsson/enminst/bin/vcs.bsh --groups | grep neo | grep ONLINE | awk '{print $3}' | head -1)
    POSTGRES_HOSTNAME=$(/opt/ericsson/enminst/bin/vcs.bsh --groups | grep postgres | grep ONLINE | awk '{print $3}')
    backup_log=$(ls -ltr /opt/ericsson/itpf/bur/log/brs/backup | tail -1 | awk '{print $NF}')
    neo_leader=$(${sshvm} ${neo_instance} '/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action cluster_overview' | grep LEADER | awk -F ":" '{print $1}')
    neo4j_cluster_type=$(egrep "neo4j_cluster" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}')
    svc_CM_vip_ipaddress=$(grep svc_CM_vip_ipaddress /software/autoDeploy/MASTER_siteEngineering.txt | awk -F "=" '{print $2}')
    svc_CM_vip_ipv6address=$(grep svc_CM_vip_ipv6address /software/autoDeploy/MASTER_siteEngineering.txt | awk -F "=" '{print $2}')

    if [ -e /etc/cron.d/stkpi_CM_Synch_01 ]; then
      stkpi_erbs=$(cat /etc/cron.d/stkpi_CM_Synch_01 | head -1 | awk -F "_" '{print $NF}')
      stkpi_netsim=$(ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep -ril ${stkpi_erbs} /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP 'ieatnetsimv[0-9]{4}-[0-9]{2}'")
      stkpi_sim=$(ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep ${stkpi_erbs} -ri /opt/ericsson/enmutils/etc/nodes/| grep -v failed | grep -oP "\"html.*ieat"\" " | awk -F ", " '{print $2}')
    fi

  fi
}

read_rv_dailychecks_tmp() {
  sleep 15
  if [ -s "${rv_dailychecks_tmp_file}" ]; then
    cat ${rv_dailychecks_tmp_file} | sed "s/^/\t/g"
    truncate -s 0 ${rv_dailychecks_tmp_file}
  else
    echo "No entries" | sed "s/^/\t\t/g"
  fi
}

nodemappings() {
  CLUSTER_TYPE=$1
  [[ -z $CLUSTER_TYPE ]] && {
    printf "Show mapping between litp node and hostname.\nUsage: $FUNCNAME cluster_type\n where node_type=all, svc, scp or db etc\n"
    return
  }
  [[ "$CLUSTER_TYPE" == "all" ]] && CLUSTER_LIST=$(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}') || CLUSTER_LIST=$CLUSTER_TYPE
  for CLUSTER in $CLUSTER_LIST; do
    NODE_LIST=$(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/ | egrep -v ':|^/' | awk -F'/' '{print $NF}')
    for NODE in $NODE_LIST; do
      echo $NODE: $(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/$NODE | egrep hostname | awk '{print $NF}')
    done
  done
}

service_reg_consul_checks() {
  if [ ${env_type} == "cloud" ]; then
    echo
    echo -e "\e[0;32mService Registry & Consul Status: \e[0m"
    echo -e "\e[0;32m=================================\e[0m"
    echo -e "\e[0;35mService Registry Status: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "sudo consul operator raft --list-peers" | sed "s/^/\t/g"
    echo
    echo -e "\e[0;35mList of any Consul members in status left: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "sudo consul members | egrep 'left|Status'" | sed "s/^/\t/g"
    echo
    echo -en "\e[0;35mCount of # of Consul members: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "sudo consul members | wc -l"
    echo
    echo -e "\e[0;35mVNF-LAF Consul EventMemberJoin / EventMemberLeave events: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP 'sudo cat /var/log/messages | grep "$(date +%b" "%d)".*consul.*Member' | sed "s/^/\t/g"
    if [ $? -eq 0 ]; then
      echo "None" | sed "s/^/\t/g"
    fi
  fi
}

cm_cm_nbi() {
  echo
  echo -e "\e[0;32mCM_NBI: \e[0m"
  echo -e "\e[0;32m=======\e[0m"
  grep -i nbi_cm /var/log/messages | tail -18 | sed "s/^/\t/g"
  echo
  echo -e "\e[0;32mcm_events_nbi in SOLR:\e[0m" | sed "s/^/\t/g"
  curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=cm_events_nbi&wt=json&indent=true&memory=true' | egrep 'name|numDocs' | sed "s/^/\t/g"
  echo

  lastest_cmnbi_time=$(grep -i nbi_cm /var/log/messages | tail -1 | awk -F " " '{print $3}')
  convert_time_to_seconds ${lastest_cmnbi_time}
  cmnbi_time_in_secs=${time_in_secs}

  convert_time_to_seconds $(date +%H:%M:%S)
  current_time_in_secs=${time_in_secs}

  time_diff=$((current_time_in_secs - cmnbi_time_in_secs))

  if [ ${time_diff} -gt 300 ]; then
    echo -e "\e[0;31m*********CM_NBI IS NOT CURRENTLY RUNNING*********\e[0m" | sed "s/^/\t/g"
  else
    echo -e "\e[0;32m********CM NBI IS CURRENTLY RUNNING*********\e[0m" | sed "s/^/\t/g"
  fi

}

pm_stats() {
  echo
  echo -e "\e[0;32mPM_COLLECTION_STATISTICS: \e[0m"
  echo -e "\e[0;32m========================\e[0m"
  #/root/rvb/bin/Quick_PM_data_Check.sh | sed "s/^/\t\t/g"

  #echo "select T2.node_type,case when T2.filetype like '1.bin.gz' then 'Low_Prio_CellTrace' when T2.filetype like '3.bin.gz' then 'High_Prio_CellTrace' when T2.filetype like 'statsfile%' then 'PM_Statistical' when T2.filetype like 'uetracefile%' then 'PM_UETrace' when T2.filetype like 'uetrfile.bin.gz' then 'UETR' when T2.filetype like 'ctrfile.bin.gz' then 'CTR' when T2.filetype like 'rnc_gpehfile' then 'UETR' when (T2.node_type='ERBS' OR T2.node_type='RadioNode') AND (T2.filetype like '1.xml.gz%') then 'PM_EBSL' when (T2.node_type='SGSN-MME') AND (T2.filetype like '1.xml.gz%') then 'PM_EBSM_3GPP/ENIQ' when (T2.node_type='RNC') AND (T2.filetype like 'uetrfile.bin.gz%') then 'RNC_UETR' when (T2.node_type='RNC') AND (T2.filetype like 'ctrfile.bin.gz%') then 'RNC_CTR' when (T2.node_type='RNC') AND (T2.filetype like 'rnc_gpehfile.bin.gz%') then 'RNC_GPEH' when T2.filetype like 'ctum.%' then 'PM_CTUM' else T2.fileType end file_Type,T2.files_collected,T2.total_nodes from (select T1.node_type,T1.fileType,T1.files_collected,T1.total_nodes from (select node_type,split_part(file_location, '_', (length(file_location)-(length(replace(file_location, '_', '')))+1)) as fileType,count(*) as files_collected,case when node_type like 'ERBS' then '${nE}' when node_type like 'MGW' then '${nM}' when node_type like 'RNC' then '${nRNC}' when node_type like 'RadioNode' then '${nR}' when node_type like 'SGSN-MME' then '${nS}' when node_type like 'Router6672' then '${nS1}' end total_nodes from pm_rop_info where file_location like '%%A${1}.${2}%' and node_type in ('ERBS','MGW','RadioNode','SGSN-MME','Router6672','RNC') group by node_type,substring(split_part(file_location, '/', 6) from 1 for 19),split_part(file_location, '_', (length(file_location)-(length(replace(file_location, '_', '')))+1)) order by node_type) T1 group by T1.node_type,T1.fileType,T1.files_collected,T1.total_nodes order by T1.node_type,T1.fileType,T1.files_collected,T1.total_nodes) T2 group by T2.node_type,T2.filetype,T2.files_collected,T2.total_nodes order by T2.node_type,T2.filetype,T2.files_collected,T2.total_nodes;" > /tmp/pmic.sql
  #echo -e "\e[0;33mExecuting Query for ROP \e[0m $1 $2"| sed "s/^/\t/g"
  #echo "======================================"| sed "s/^/\t/g"
  #ser=`/opt/ericsson/enminst/bin/vcs.bsh --groups|grep postgres|grep ONLINE|awk '{print $3}'`
  #/usr/bin/psql -h ${ser} -U postgres -d flsdb -f /tmp/pmic.sql -q| sed "s/^/\t/g"
  #echo -e "\e[0;33m********** END of QUERY Execution *********** \e[0m"| sed "s/^/\t/g"
  #rm -f /tmp/pmic.sql

  echo
  echo -e "\e[0;32mPM File Collection Locations set in ENM:\e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * PmMeasurementCapabilities.fileLocation -t" | awk '{print $NF}' | egrep -v "PmMeasurementCapabilities|fileLocation|instance" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"

  echo
  echo -e "\e[0;32mPM NBI Status - Latest PM_26 NBI File Transfer Results:\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} == "cloud" ]; then
    test -e /var/log/enmutils/daemon/pm_26.log
    if [ $? -eq 0 ]; then
      grep -i "PM_26 NBI file transfer results" /var/log/enmutils/daemon/pm_26.log | grep -v "Failures occurred" | tail -16 | cut -d " " -f1-2,11- | sed "s/^/\t\t/g"
      echo
      echo -e "\e[0;35mPM NBI Status - Occurrences where PM ROPs sent NorthBound failed on $(date +%b" "%d):\e[0m" | sed "s/^/\t/g"
      grep -i "PM_26 NBI file transfer results" /var/log/enmutils/daemon/pm_26.log | cut -d " " -f1-2,11- | grep "$(date +%Y-%m-%d).*SUCCESS: False" | sed "s/^/\t\t/g"
    else
      echo -e "\e[0;31mPM_NBI has not been setup. Workload Profile PM_26 needs to be started.\e[0m" | sed "s/^/\t\t/g"
    fi
  else
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "test -e /var/log/enmutils/daemon/pm_26.log"
    if [ $? -eq 0 ]; then
      ssh -o StrictHostKeyChecking=no $WORKLOAD_VM 'grep -i "PM_26 NBI file transfer results" /var/log/enmutils/daemon/pm_26.log | grep -v "Failures occurred" | tail -16 | cut -d " " -f1-2,11-' | sed "s/^/\t\t/g"
      echo
      echo -e "\e[0;35mPM NBI Status - Occurrences where PM ROPs sent NorthBound failed on $(date +%b" "%d):\e[0m" | sed "s/^/\t/g"
      ssh -o StrictHostKeyChecking=no $WORKLOAD_VM 'grep -i "PM_26 NBI file transfer results" /var/log/enmutils/daemon/pm_26.log | cut -d " " -f1-2,11-' | grep "$(date +%Y-%m-%d).*SUCCESS: False" | sed "s/^/\t\t/g"
    else
      echo -e "\e[0;31mPM_NBI has not been setup. Workload Profile PM_26 needs to be started.\e[0m" | sed "s/^/\t\t/g"
    fi
  fi
}

db_versant_trans() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mList of current Longest Transactions in Versant:\e[0m"
    echo -e "\e[0;32m================================================\e[0m"
    ${sshvm} db1-service "su - versant -c "\""/ericsson/versant/bin/dbtool -nosession -trans -info -xa dps_integration"\"" | sort -nrk 5|head -10 > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
  fi
}

cm_solr() {
  echo
  echo -e "\e[0;32mCurrent Number of Documents stored in SOLR: \e[0m"
  echo -e "\e[0;32m===========================================\e[0m"
  echo -e "\e[0;35mCollection1:\t\t\e[0m" | sed "s/^/\t/g"

  if [ ${env_type} == "cloud" ]; then
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "curl -s "\""http://${solr_hostname}:8983/solr/admin/cores?action=STATUS&core=collection1&wt=json&indent=true&memory=true"\""|egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'"
  else
    curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=collection1&wt=json&indent=true&memory=true' | egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'
  fi

  echo ""
  echo -e "\e[0;35mCM_Events_NBI:\t\t\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} == "cloud" ]; then
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "curl -s "\""http://${solr_hostname}:8983/solr/admin/cores?action=STATUS&core=cm_events_nbi&wt=json&indent=true&memory=true"\""|egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'"
  else
    curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=cm_events_nbi&wt=json&indent=true&memory=true' | egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'
  fi

  echo ""
  echo -e "\e[0;35mCM_History:\t\t\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} == "cloud" ]; then
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "curl -s "\""http://${solr_hostname}:8983/solr/admin/cores?action=STATUS&core=cm_history&wt=json&indent=true&memory=true"\""|egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'"
  else
    curl -s 'http://solr:8983/solr/admin/cores?action=STATUS&core=cm_history&wt=json&indent=true&memory=true' | egrep -w 'name|numDocs|maxDoc|startTime|instanceDir|dataDir|directory|size|deletedDocs'
  fi
}

cm_list_unsynched_nodes() {
  echo
  echo -e "\e[0;32mList of Nodes NOT CM SYNCHRONIZED: \e[0m"
  echo -e "\e[0;32m==================================\e[0m"
  ${CLI_APP} "cmedit get * CmFunction.syncStatus!=SYNCHRONIZED -t" | grep -v ERS | sed "s/^/\t/g"
}

db_vcc_checks() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mResults of Versant Consistency Check for $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m===============================================\e[0m"
    ${sshvm} db1-service "egrep 'started at|Started backup of|Successfully copied files|Finished backup of|done successfully at|Start consistency check at|Versant Inconsistencies detected|DPS Consistency check|Consistency check done' /var/log/messages | egrep "\""${VCC_DATE1}|${VCC_DATE2}"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
    echo ""
    echo -e "\e[0;35mFor full details run:\e[0m \e[0;33msshvm db1-service "\""egrep "\'"backup_database|backup_and_consistency_check_database|consistency_check_database|dps_consistency_check_run"\'" /var/log/messages"\"" | egrep "\'"${VCC_DATE1}|${VCC_DATE2}"\'" \e[0m" | sed "s/^/\t/g"
  fi
}

db_postgres_checks() {
  echo
  echo -e "\e[0;32mDB Postgres Checks: \e[0m"
  echo -e "\e[0;32m==================\e[0m"
  #${sshvm} ${POSTGRES_HOSTNAME} "/opt/ericsson/pgsql/util/postgres_admin.sh -V -U -C -S -R > ${rv_dailychecks_tmp_file}" &> /dev/null
  ${sshvm} postgresql01 "/opt/ericsson/pgsql/util/postgres_admin.sh -V -U -C -S -R > ${rv_dailychecks_tmp_file}" &>/dev/null
  sleep 10
  read_rv_dailychecks_tmp
}

snapshot_size() {
  echo
  echo -e "\e[0;32mSnapshot Sizes: \e[0m"
  echo -e "\e[0;32m===============\e[0m"
  ${lvs} >${rv_dailychecks_tmp_file}
  read_rv_dailychecks_tmp
}
convert_time_to_seconds() {
  time_in_secs=$(echo $1 | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
}

db_long_living_trans() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mLong Living Transactions on $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m==================================\e[0m"
    zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed 's/#012/\n/g' | sed 's/#011/\t/g' | egrep --colour 'transaction ID|Transaction Info' | grep -oP 'Transaction Info .* Seconds' --colour | sort | uniq -c | sed "s/^/\t/g"
  fi
}

db_optimistic_lock_trans() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mOptimistic Lock Transactions on $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m======================================\e[0m"
    zgrep 'OptimisticLockException' /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/$(date +%d%m%y)/enmlogs/*csv.gz | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep -oP '@svc-.*-.*@JBOSS@' | sort | uniq -c | sort -rnk 1 | sed "s/^/\t/g"
  fi
}

db_dead_trans_count() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mCount of Dead locks on $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m=============================\e[0m"
    cat /ericsson/enm/dumps/longesttransactions_rvb_${DATE}.log | grep dead -c | sed "s/^/\t/g"
  fi
}

db_dead_trans_list() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mList of Dead locks on $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m============================\e[0m"
    egrep --colour 'IST|GMT|dead' /ericsson/enm/dumps/longesttransactions_rvb_${DATE}.log | grep dead -B1 | sed "s/^/\t/g"
  fi
}

db_dead_lock_trans() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mDead Lock Count on $(date +%b" "%d): \e[0m"
    echo -e "\e[0;32m=========================\e[0m"
    zgrep 'DEADLOCK' /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/$(date +%d%m%y)/enmlogs/*csv.gz | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep -oP '@svc-.*-.*@JBOSS@' | sort | uniq -c | sort -rnk 1 | sed "s/^/\t/g"
  fi
}

cm_network_status() {
  echo
  echo -e "\e[0;32mCurrent Network Status: \e[0m"
  echo -e "\e[0;32m======================\e[0m"
  ${NETWORK} status --groups --sl | sed "s/^/\t/g"
}

cm_node_numbers() {
  echo
  echo -e "\e[0;32mNumber of NEs in the network: \e[0m"
  echo -e "\e[0;32m=============================\e[0m"
  for TYPE in $(${CLI_APP} "cmedit get * NetworkElement.neType -ns=OSS_NE_DEF" | grep neType | cut -d":" -f2 | sort -u); do
    echo -en "${TYPE}:\t"
    ${CLI_APP} "cmedit get * NetworkElement -ns=OSS_NE_DEF -ne=${TYPE} -cn" | tail -1
  done | sed "s/^/\t/g"
  echo -en "Mixed Mode RadioNodes (technologyDomain = UMTS & EPS): " | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit get * NetworkElement.technologyDomain -t' | grep UMTS | grep -v SGSN | grep EPS -c | sed "s/^/\t/g"
}

network_breakdown() {
  echo
  echo -e "\e[0;32mBreakdown of Network: \e[0m"
  echo -e "\e[0;32m=====================\e[0m"
  for i in {BSC,COM,CPP,Er6000,Esc,FrontHaul6080,GenericFmNode,MINILINKIndoor,MINILINKOutdoor,MSC,STN}; do
    echo -en "Size of $i Network:\t"
    ${CLI_APP} "cmedit get * ${i}ConnectivityInformation.ipAddress -cn" | tail -1
  done | sed "s/^/\t/g"
}

platform_type() {
  echo
  echo -e "\e[0;32mBreakdown of Nodes by NetworkElement.platform type: \e[0m"
  echo -e "\e[0;32m===================================================\e[0m"
  ${CLI_APP} "cmedit get * NetworkElement.platformType -t" | egrep -v "instance|Network|NodeId" | awk '{print $2}' | sort | uniq -c | sed "s/^/\t/g"
}

fm_nbi() {
  echo
  echo -e "\e[0;32mFM NBI Status: \e[0m"
  echo -e "\e[0;32m==============\e[0m"
  echo -e "\e[0;35mNumber of FM Corba NBI clients running: \e[0m" | sed "s/^/\t/g"
  ${sshvm} svc-1-nbalarmirp "cd /opt/ericsson/com.ericsson.oss.nbi.fm/test_client/;./testclient.sh subscriptionData | grep "\""active subscription(s) available in the system"\"" --colour > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
  echo ""
  echo -e "\e[0;35mNumber of FM SNMP NBI clients running: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'fmsnmp get nmslist' | tail -1 | sed "s/^/\t\t/g"
  echo ""
  if [ ${env_type} = physical ]; then
    echo -e "\e[0;35mFM Corba NBI clients running on ${WORKLOAD_VM}: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "ps -ef | grep [T]estClient |wc -l" | sed "s/^/\t\t/g"
  else
    ps -ef | grep [T]estClient | wc -l | sed "s/^/\t\t/g"
  fi
}

fm_node_status() {
  echo
  echo -e "\e[0;32mFM Node Status: \e[0m"
  echo -e "\e[0;32m===============\e[0m"
  for TYPE in $(/opt/ericsson/enmutils/bin/cli_app "cmedit get * NetworkElement.neType" | grep neType | cut -d":" -f2 | sort -u); do
    echo ${TYPE}
    /opt/ericsson/enmutils/bin/cli_app "cmedit get * FmFunction.currentServiceState -ne=${TYPE}" | grep currentServiceState | cut -d":" -f2 | sort | uniq -c
  done | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mDistribution of nodes across FM Mediation Service instances (FmRouterPolicyMappings.txt): \e[0m" | sed "s/^/\t/g"
  strings /ericsson/tor/data/fm/fmrouterpolicy/data/FmRouterPolicyMappings.txt | grep -oP 'svc.*service' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e -n "\e[0;35mTotal Nodes FM supervised is: \e[0m" | sed "s/^/\t/g"
  strings /ericsson/tor/data/fm/fmrouterpolicy/data/FmRouterPolicyMappings.txt | grep -c svc | sed "s/^/\t/g"
}

network_status_check() {
  echo
  echo -e "\e[0;32mOverview of Network Status: \e[0m"
  echo -e "\e[0;32m===========================\e[0m"
  /root/rvb/bin/network_status_check.bsh | sed "s/^/\t/g"
}

local_file_system_sizes() {
  echo
  echo -e "\e[0;32mLocal File System Sizes: \e[0m"
  echo -e "\e[0;32m========================\e[0m"
  df -hTP | grep -v ddpenm | sort -nk6 | sed "s/^/\t/g"
}

enm_baseline() {
  echo
  echo -e "\e[0;32mCurrent ENM Baseline & ENM URL: \e[0m"
  echo -e "\e[0;32m===============================\e[0m"
  if [ ${env_type} = cloud ]; then
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} 'consul kv get "enm/deployment/enm_version"' | sed "s/^/\t/g"
    echo -en "\e[0;35mENM URL:\t\e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "consul kv get enm/deprecated/global_properties/web_host_default"

  else
    echo -e "\e[0;35mCurrent installed ENM version:\e[0m" | sed "s/^/\t/g"
    cat /etc/enm-version | sed "s/^/\t/g"
    echo ""
    echo -e "\e[0;35mENM History Info:\e[0m" | sed "s/^/\t/g"
    cat /etc/enm-history | sed "s/^/\t/g"
    echo ""
    echo -en "\e[0;35mENM URL:\t\e[0m" | sed "s/^/\t/g"
    grep web_host_default /ericsson/tor/data/global.properties | awk -F "=" '{print $2}'

  fi
}

litp_baseline() {
  if [ ${env_type} = physical ]; then
    echo
    echo -e "\e[0;32mCurrent LITP Baseline: \e[0m"
    echo -e "\e[0;32m=====================\e[0m"
    echo -e "\e[0;35mCurrent installed LITP version:\e[0m" | sed "s/^/\t/g"
    cat /etc/litp-release | sed "s/^/\t/g"
    echo ""
    echo -e "\e[0;35mLITP History Info:\e[0m" | sed "s/^/\t/g"
    cat /etc/litp-history | sed "s/^/\t/g"
  fi
}

torutils_info() {
  echo
  echo -e "\e[0;32mTorutils RPM Info:\e[0m"
  echo -e "\e[0;32m==================\e[0m"
  echo -e "\e[0;35mCurrent installed version of torutils:\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM 'cat /etc/torutils-version' | sed "s/^/\t/g"
  else
    cat /etc/torutils-version | sed "s/^/\t/g"
  fi
  echo ""
  echo -e "\e[0;35mTorutils History Info:\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM 'cat /etc/torutils-history | tail -5' | sed "s/^/\t/g"
  else
    cat /etc/torutils-history | tail -5 | sed "s/^/\t/g"
  fi
  echo ""
  echo -en "\e[0;35mAPT Version Info:\t\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM '/opt/ericsson/enmutils/.env/bin/pip list --format=legacy | grep assertions' | sed "s/^/\t/g"
  else
    /opt/ericsson/enmutils/.env/bin/pip list --format=legacy | grep assertions | sed "s/^/\t/g"
  fi
  #source /opt/ericsson/enmutils/.env/bin/activate
  #pip list | grep assert
}

file_system_sizes() {
  echo
  echo -e "\e[0;32mNAS File System Sizes: \e[0m"
  echo -e "\e[0;32m======================\e[0m"
  ${sshvm} svc-1-mscm "df -hTP -x ext4|sort -nk6 > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
  echo ""

  if [ ${env_type} = physical ]; then
    echo -e "\e[0;35mElasticsearch File System details:\e[0m" | sed "s/^/\t/g"
    ${sshvm} elasticsearch "df -hTP /ericsson/elasticsearch | tail -1 > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
    echo ""
    echo -e "\e[0;35mCheck daily ES log sizes & any red/corrupted ES indices:\e[0m" | sed "s/^/\t/g"
    ${sshvm} elasticsearch "curl -G elasticsearch:9200/_cat/indices > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp

  else
    echo -e "\e[0;35mElasticsearch File System details:\e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${elasticsearch_ip} 'df -hTP /ericsson/elasticsearch | tail -1'" | sed "s/^/\t/g"
    echo ""
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${elasticsearch_ip} 'curl -G elasticsearch:9200/_cat/indices'" | sed "s/^/\t/g"
  fi

  echo
  echo -e "\e[0;32mNote:\e[0m indices are located here: /ericsson/elasticsearch/data56/nodes/0/indices/ on the ES node/VM." | sed "s/^/\t/g"
}

cm_import_status() {
  echo
  echo -e "\e[0;32mCM Import Status for $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m============================\e[0m"
  echo -e "\e[0;35mNumber of Imports up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit import -st' | egrep "$(date +%Y-%m-%d)" | wc -l | sed "s/^/\t/g"
  echo ""
  #       echo -e "\e[0;35m5k MO Import Change (STKPI - CMIMPORT_05) on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  #               ${CLI_APP} 'cmedit import -st'| egrep "Job|$(date +%Y-%m-%d)" | cut -f1-5,9,12- |egrep "cm_import_05|Status" | sed "s/^/\t/g"
  #               echo ""
  echo -e "\e[0;35mList of failed Imports up to $(date): \e[0m" | sed "s/^/\t/g"
  #        ${CLI_APP} 'cmedit import -st'| egrep "Job|$(date +%Y-%m-%d)" | egrep -i "failed|Status" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit import -st' | egrep "Job|$(date +%Y-%m-%d)" | cut -f1-5,13- | egrep -i "failed|Status" | sed "s/^/\t/g"
}

cm_activations_status() {
  echo
  echo -e "\e[0;32mCM Activations Status for $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=================================\e[0m"
  ${CLI_APP} 'config activate -st' | egrep "Job|$(date +%Y-%m-%d)" | sed "s/^/\t/g"
}

config_copy_info() {
  echo
  echo -e "\e[0;32mConfig Copy Jobs on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m===========================\e[0m"
  ${CLI_APP} 'config copy -st' | egrep "Job|$(date +%Y-%m-%d)" | sed "s/^/\t/g"
}

config_delete_info() {
  echo
  echo -e "\e[0;32mConfig Delete Jobs on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=============================\e[0m"
  ${CLI_APP} 'config delete -st' | egrep "Job|$(date +%Y-%m-%d)" | sed "s/^/\t/g"
}

cm_revocation_info() {
  echo
  echo -e "\e[0;32mCM Revocation Job Status for $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m====================================\e[0m"
  echo -e "\e[0;35mNumber of CM Revocations up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'config undo -st' | egrep "^Job|$(date +%Y-%m-%d)" | sed "s/^/\t/g"
  #        ${CLI_APP} 'config undo -st'| egrep "^Job|$(date +%Y-%m-%d)" > ${rv_dailychecks_tmp_file}
  #        cat ${rv_dailychecks_tmp_file} | grep -vi "^Job" | wc -l | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of failed CM Revocation Jobs on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -i "^Job|failed" | sed "s/^/\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

cm_export_status() {
  echo
  echo -e "\e[0;32mCM Export Status for $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m============================\e[0m"
  echo -e "\e[0;35mNumber of Exports up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit export -st' | egrep "$(date +%Y-%m-%d)" | wc -l | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFull Network Exports (STKPI - CMEXPORT_01) on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit export -st' | egrep "Job|$(date +%Y-%m-%d)" | cut -f1-8,11 | egrep -i "Status|cmexport_01" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mSTKPI CM_Export_01 results on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"

  for i in $(grep impexpserv /etc/hosts | awk '{print $2}'); do
    ${sshvm} $i "grep "\""$(date +%Y-%m-%d).*EXPORT_SERVICE.COMPLETED"\"" /ericsson/3pp/jboss/standalone/log/server.log* |egrep 'T06|T22' |cut -d, -f7,8,9,10,11,13,14,16,17 |tr -s ',' ' '|tr -s '=' ' ' >> ${rv_dailychecks_tmp_file}" &>/dev/null
  done
  if [ -e ${rv_dailychecks_tmp_file} ]; then
    while read line; do
      LINE=$(echo "$line" | cut -d, -f7,8,9,10,11,13,14,16,17 | tr -s "," " " | tr -s "=" " " | awk '{print $6" | STATUS: "$4" | TIME_TOOK: "$10"sec | NODES: "$12"/"$16" | MOs: "$18" |" }')
      LINE_1=$(echo "$line" | cut -d, -f7,8,9,10,11,13,14,16,17 | tr -s "," " " | tr -s "=" " ")
      n4=$(echo "$LINE_1" | awk '{print $18}')
      d4=$(echo "$LINE_1" | awk '{print $10}')
      r4=$(echo "scale=0;(${n4}/${d4})" | bc)
      printf "$LINE  " | sed "s/^/\t/g"
      echo -e "\e[0;34mSTKPI Result: ${r4} MO/sec\e[0m"
    done <${rv_dailychecks_tmp_file}
  fi

  >${rv_dailychecks_tmp_file}
  echo
  echo -e "\e[0;35mSummary of ENIQ Exports on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit export -st' | egrep "Job|$(date +%Y-%m-%d)" | cut -f1-8,11 | egrep -i "Status|eniq" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of Failed/Ongoing Exports up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit export -st' | egrep "Job|$(date +%Y-%m-%d)" | cut -f1-5,9-11,13- >${rv_dailychecks_tmp_file}
  cat ${rv_dailychecks_tmp_file} | awk '$6 > 0 {print}' | sed "s/^/\t/g"
  echo ""
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

cm_nhc_status() {
  echo
  echo -e "\e[0;32mNode Health Check Status for $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m====================================\e[0m"
  echo -e "\e[0;35mNumber of Node Health Check jobs run up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'nhc rep --status' | egrep $(date +%Y-%m-%d) | wc -l | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of failed Node Health Check Jobs up to $(date): \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'nhc rep --status' | egrep "Job|Name|$(date +%Y-%m-%d)" | grep -i "failure" | wc -l | sed "s/^/\t/g"
  echo ""
}

cm_configs() {
  echo
  echo -e "\e[0;32mCurrent List of Configs: \e[0m"
  echo -e "\e[0;32m========================\e[0m"
  ${CLI_APP} 'config list --verbose' | sed "s/^/\t/g"
}

check_ddp_mountpoint() {
  echo
  echo -e "\e[0;32mChecking if ${ddp_server} File System is mounted \e[0m"
  echo -e "\e[0;32m=============================================\e[0m"
  [[ -z $(mount | egrep ${ddp_server}: | grep net) ]] && mkdir -p /net/${ddp_server}/data/stats && mount ${ddp_server}:/data/stats /net/${ddp_server}/data/stats && echo "${ddp_server} File System is now mounted" || echo "${ddp_server} File System is already mounted" | sed "s/^/\t/g"
}

db_opendj_replication_status() {
  echo
  echo -e "\e[0;32mChecking Opendj Replication Status: \e[0m"
  echo -e "\e[0;32m=============================================\e[0m"
  ${sshvm} db-1 '/opt/opendj/bin/status -w ldapadmin -D "cn=Directory Manager" | grep Replication' | sed "s/^/\t/g"
  echo ""
  ${sshvm} db-1 "/opt/opendj/bin/dsreplication status --baseDN "\""$(grep COM_INF_LDAP_ROOT_SUFFIX /ericsson/tor/data/global.properties | cut -d '=' -f 2-)"\"" --adminUID repadmin --adminPassword ldapadmin --hostname opendjhost0 --port 4444 -X -n > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
}

cm_unsynched_nodes_by_type() {
  echo
  echo -e "\e[0;32mNumber of nodes unsynched per Node Type: \e[0m"
  echo -e "\e[0;32m========================================\e[0m"
  for TYPE in $(${CLI_APP} "cmedit get * NetworkElement.neType" | grep neType | cut -d":" -f2 | sort -u); do
    echo -n "${TYPE} "
    ${CLI_APP} "cmedit get * CmFunction.syncStatus!=SYNCHRONIZED -ne=${TYPE} -cn" | grep -v found
  done | sed "s/^/\t/g"
}

cm_network_cell_count() {
  echo
  echo -e "\e[0;32mNumber of cells in the network: \e[0m"
  echo -e "\e[0;32m===============================\e[0m"
  ${CLI_APP} 'cmedit get * EUtranCellFDD;EUtranCellTDD;UtranCell;GeranCell -cn' | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of LOCKED EUtranCellFDD cells for STKPI:\e[0m" | sed "s/^/\t/g"
  echo -en "ERBS:\t" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * EUtranCellFDD.administrativeState==LOCKED -netype=ERBS -cn" | tail -1 | sed "s/^/\t/g"
  echo -en "RadioNode:\t" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * EUtranCellFDD.administrativeState==LOCKED -netype=RadioNode -cn" | tail -1 | sed "s/^/\t/g"
}

list_dumps() {
  echo
  echo -e "\e[0;32mThread / Versant / Heap / Core / GC Dumps Info:\e[0m"
  echo -e "\e[0;32m===============================================\e[0m"

  #****ssh -o StrictHostKeyChecking=no -tt -i /var/tmp/enm_keypair.pem cloud-user@${EMP} "exec sudo -i" "/bin/find /ericsson/enm/dumps/ | grep hprof | xargs ls -ltrh | grep hprof" | sed "s/^/\t/g

  echo -e "\e[0;35mList of thread dumps:\e[0m" | sed "s/^/\t/g"
  if [ -d /ericsson/enm/dumps/thread_dumps ]; then /bin/ls -ltrh /ericsson/enm/dumps/thread_dumps; else echo "None"; fi | sed "s/^/\t/g"
  echo ""
  if [ ${dps_persistence_provider} = versant ]; then
    echo -e "\e[0;35mList of versant dumps:\e[0m" | sed "s/^/\t/g"
    if [ -d /ericsson/enm/dumps/versant ]; then /bin/ls -ltrh /ericsson/enm/dumps/versant; else echo "None"; fi | sed "s/^/\t/g"
    echo ""
  fi
  echo -e "\e[0;35mList of Heap dumps:\e[0m" | sed "s/^/\t/g"
  /bin/find /ericsson/enm/dumps/ | grep hprof | xargs ls -ltrh | grep hprof | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of Neo4j Heap dumps:\e[0m" | sed "s/^/\t/g"
  /bin/ls -ltrh /ericsson/enm/dumps/neo4j | grep hprof | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of Core dumps:\e[0m" | sed "s/^/\t/g"
  /bin/ls -ltrh /ericsson/enm/dumps/ | grep " core.*" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of GC dumps:\e[0m" | sed "s/^/\t/g"
  if [ -d /ericsson/enm/dumps/gc_dumps ]; then /bin/ls -ltrh /ericsson/enm/dumps/gc_dumps; else echo "None"; fi | sed "s/^/\t/g"
  echo ""
}

db_versant_fragmentation_report() {
  echo
  echo -e "\e[0;32mVersant Node Fragmentation Report: \e[0m"
  echo -e "\e[0;32m=================================\e[0m"
  ${sshvm} db1-service "/opt/VRTS/bin/fsadm -E /ericsson/versant_data > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
}

cm_amos_sessions() {
  echo
  echo -e "\e[0;32mNumber of AMOS Sessions: \e[0m"
  echo -e "\e[0;32m========================\e[0m"
  for i in {1..4}; do
    echo "scp-$i-amos"
    ${sshvm} scp-$i-amos '/opt/ericsson/amos/moshell/pstool list' | grep "Moshell Sessions"
    echo ""
  done | sed "s/^/\t/g"
  for i in {1..3}; do
    echo "scp-$i-scripting"
    ${sshvm} scp-$i-scripting '/opt/ericsson/amos/moshell/pstool list' | grep "Moshell Sessions"
    echo ""
  done | sed "s/^/\t/g"
}

netsim_rnc_bandwidth_setting() {
  echo
  echo -e "\e[0;32mCheck Bandwidth setting for all RNC simulations: \e[0m"
  echo -e "\e[0;32m================================================\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep -ril RNC /opt/ericsson/enmutils/etc/nodes/ &> /dev/null"
    if [ $? -eq 0 ]; then
      #           for i in `grep -ril RNC /opt/ericsson/enmutils/etc/nodes/ | grep -vi failed | awk -F "/" '{print $NF}' | awk -F "." '{print $1}' | grep -oP "ieatnetsimv[0-9]{4}-[0-9]{2,3}" |sort | uniq`;do echo -ne "${i}\t"; ssh root@${i} "/netsim_users/pms/bin/limitbw -n -s | grep RNC | grep -v RBS";done | sed "s/^/\t/g"
      for i in $(grep -ril RNC /opt/ericsson/enmutils/etc/nodes/ | grep -vi failed | grep -oP "ieatnetsimv[0-9]{4}-[0-9]{2,3}" | sort | uniq); do
        echo -ne "${i}\t"
        ssh root@${i} "/netsim_users/pms/bin/limitbw -n -s | grep RNC | grep -v RBS"
      done | sed "s/^/\t/g"
    else
      echo -e "No RNCs in this deployment" | sed "s/^/\t/g"
    fi
  else
    grep -ril RNC /opt/ericsson/enmutils/etc/nodes/ &>/dev/null
    if [ $? -eq 0 ]; then
      for i in $(grep -ril RNC /opt/ericsson/enmutils/etc/nodes/ | grep -vi failed | grep -oP "ieatnetsimv[0-9]{4}-[0-9]{2,3}" | sort | uniq); do
        echo -ne "${i}\n"
        ssh root@${i} '/netsim_users/pms/bin/limitbw -n -s | grep RNC | grep -v RBS | sort | sed "s/^/\t/g" '
      done | sed "s/^/\t/g"
    else
      echo -e "No RNCs in this deployment" | sed "s/^/\t/g"
    fi
  fi
}

mo_numbers() {
  echo
  echo -e "\e[0;32mMO Numbers: \e[0m"
  echo -e "\e[0;32m===========\e[0m"
  echo -e "\e[0;35m# Managed Element MOs: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * ManagedElement -cn" | tail -1 | sed "s/^/\t/g"
  echo -e "\e[0;35m# ENodebFunction MOs: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * ENodebFunction -cn" | tail -1 | sed "s/^/\t/g"
  echo -e "\e[0;35m# Network Element MOs: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * NetworkElement -ns=OSS_NE_DEF -cn" | tail -1 | sed "s/^/\t/g"
  echo -e "\e[0;35m# Synched Nodes: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * CmFunction.syncStatus==SYNCHRONIZED -cn" | tail -1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35m# SGSN-MME SystemFunctions MOs:\e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * SystemFunctions -ne=SGSN-MME " | tail -1 | sed "s/^/\t/g"
  echo -e "\e[0;35m# SGSN-MMEs Synched:\e[0m" | sed "s/^/\t/g"
  ${CLI_APP} "cmedit get * CmFunction.syncStatus -ne=SGSN-MME -cn" | tail -1 | sed "s/^/\t/g"
}

user_info() {
  echo
  echo -e "\e[0;32mUser Information:\e[0m"
  echo -e "\e[0;32m=================\e[0m"
  ${user_mgr} list | grep "NUMBER OF USERS LISTED" | sed "s/^/\t/g"
  echo ""
  #        echo -e "\e[0;35mBreakdown of Users created:\e[0m" | sed "s/^/\t/g"
  #        ${user_mgr} list --limit=all | egrep "Administrator|Operator"| awk -F "_" '{print $1,$2}' | uniq -c | sort -nk1 | sed "s/^/\t/g"
  echo -e "\e[0;32mTotal # of Users in postgres:\e[0m"
  echo -e "\e[0;32m=============================\e[0m"
  ${sshvm} postgresql01 "export PGPASSWORD=P0stgreSQL11;/opt/rh/postgresql92/root/usr/bin/psql -h postgresql01 -U postgres -d idenmgmt -c "\""select count(*) from postgre_user"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
}

fm_hb_failure() {
  echo
  echo -e "\e[0;32mList of nodes in HB Failure state: \e[0m"
  echo -e "\e[0;32m==================================\e[0m"
  ${CLI_APP} "alarm status * -fail" | sed "s/^/\t/g"
}

fm_enm_alarms() {
  echo
  echo -e "\e[0;32mSummary of ENM Management System FM Alarm Specific Problems reported for today: \e[0m"
  echo -e "\e[0;32m===============================================================================\e[0m"
  ${CLI_APP} "alarm get ENM -b $(date +%Y-%m-%d) -e $(date +%Y-%m-%d)" | egrep -v "presentSeverity|Total number of alarms fetched for the given query" >${rv_dailychecks_tmp_file}
  for i in $(awk '{print $1}' ${rv_dailychecks_tmp_file} | uniq); do
    echo $i | sed "s/^/\t/g"
    grep $i ${rv_dailychecks_tmp_file} | awk -F "\t" {'print $3}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  done
  echo ""
  echo -e "\e[0;35mFor full details run: \e[0m cli_app "\""alarm get ENM -b $(date +%Y-%m-%d) -e $(date +%Y-%m-%d)"\"" " | sed "s/^/\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

fm_route_policy_status() {
  echo
  echo -e "\e[0;32mCheck Alarm Router Policy is enabled: \e[0m"
  echo -e "\e[0;32m=====================================\e[0m"
  ${CLI_APP} 'cmedit get * AlarmRoutePolicy.(name==FM_Setup_workload_policy,routeType==AUTO_ACK,enablePolicy)' | sed "s/^/\t/g"
}

fm_alarm_count() {
  echo
  echo -e "\e[0;32mFM Alarm Count: \e[0m"
  echo -e "\e[0;32m===============\e[0m"
  ${CLI_APP} 'alarm get * --count' | awk '{print $NF}' | awk -F ":" '{print $2}' | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFM Info on recent active alarm counts, acknowledgement of cleared alarms & on the number of cleared alarms: \e[0m" | sed "s/^/\t/g"
  for i in $(grep fmhistory /etc/hosts | awk '{print $2}' | sort); do
    printf "\n\n$i\n===============\n\n" >>${rv_dailychecks_tmp_file}
    ${sshvm} $i 'egrep "acknowledging all cleared" /ericsson/3pp/jboss/standalone/log/server.log | tail -5 | awk '\''{$3=$4=$5=$6=$7=$8="";print $0;}'\'' >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log;egrep "The number of  cleared alarms found for acknowledgement" /ericsson/3pp/jboss/standalone/log/server.log | tail -5 | awk '\''{$3=$4=$5=$6=$7=$8="";print $0;}'\'' >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log;egrep "Active Alarms are present" /ericsson/3pp/jboss/standalone/log/server.log | tail -5 | awk '\''{$3=$4=$5=$6=$7=$8="";print $0;}'\'' >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log ' &>/dev/null
  done
  read_rv_dailychecks_tmp
}

fmx_checks() {
  echo
  echo -e "\e[0;32mFMX Status: \e[0m"
  echo -e "\e[0;32m===========\e[0m"
  echo -e "\e[0;35mStatus of FMX modules: \e[0m" | sed "s/^/\t/g"
  ${sshvm} ${fmx} "fmxcli -c list > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
  echo ""
  echo -e "\e[0;35mFMX modules used in recent alarm filters: \e[0m" | sed "s/^/\t/g"
  ${sshvm} ${fmx} "cat /var/log/fmx/fmxie_ruletrace.log | cut -d"\"";"\"" -f6 | sort | uniq -c > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
  echo ""
  echo -e "\e[0;35mChecking FMX for any 'FM connection failures' or 'FM connection restores' in the previous 24 hours: \e[0m" | sed "s/^/\t/g"
  for i in $(grep fmx /etc/hosts | awk '{print $2}'); do
    printf "\n\n$i\n=========\n\n" >>${rv_dailychecks_tmp_file}
    ${sshvm} ${i} "zcat /var/log/fmx/fmxie-$(date +%Y-%m-%d)* | egrep 'FM connection is failing|Connection to FM restored|will re-subscribe|ENMModuleActivator' >> ${rv_dailychecks_tmp_file}" &>/dev/null
  done
  read_rv_dailychecks_tmp
  for i in $(grep fmx /etc/hosts | awk '{print $2}'); do
    printf "\n\n$i\n=========\n\n" >>${rv_dailychecks_tmp_file}
    ${sshvm} ${i} "cat /var/log/fmx/fmxie.log| egrep 'FM connection is failing|Connection to FM restored|will re-subscribe|ENMModuleActivator' >> ${rv_dailychecks_tmp_file}" &>/dev/null
  done
  read_rv_dailychecks_tmp
}

workload_status() {
  echo
  echo -e "\e[0;32mWorkload Status as at $(date): \e[0m"
  echo -e "\e[0;32m===================================================\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "${workload} status -v" | sed "s/^/\t/g"
  else
    ${workload} status -v | sed "s/^/\t/g"
  fi
}

workload_errored_nodes() {
  echo
  echo -e "\e[0;32mWorkload Errored Nodes $(date): \e[0m"
  echo -e "\e[0;32m====================================================\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "${workload} list all --errored-nodes" | sed "s/^/\t/g"
  else
    ${workload} list all --errored-nodes | sed "s/^/\t/g"
  fi
}

vcs_group_status() {
  if [ ${env_type} = physical ]; then
    echo
    echo -e "\e[0;32mList of any VCS Service Groups in Invalid state: \e[0m"
    echo -e "\e[0;32m================================================\e[0m"
    /opt/ericsson/enminst/bin/vcs.bsh --groups | grep -v OK | sed "s/^/\t/g"
  fi

}

bur_info() {
  echo

  if [ ${env_type} = physical ]; then
    ombs_policy_name=$(ssh root@${ombs_server} "/usr/openv/netbackup/bin/admincmd/bppllist | grep $(hostname) | grep SCHEDULED")
    echo -e "\e[0;32mBackup Info:\e[0m"
    echo -e "\e[0;32m============\e[0m"
    echo -en "\e[0;35mCheck if backups are currently activated: \e[0m" | sed "s/^/\t/g"
    su - brsadm -c "/opt/ericsson/itpf/bur/bin/bos --operation is_backup_activated -k ${hostname}"
    echo ""
    echo -e "\e[0;35mList of Backup Nodes:\e[0m" | sed "s/^/\t/g"
    su - brsadm -c "/opt/ericsson/itpf/bur/bin/bos --operation list_nodes" | sed "s/^/\t\t/g"
    echo ""
    if [[ ${ombs_server} == "" ]]; then
      echo "Netbackup not configured. No backup server configured in /usr/openv/netbackup/bp.conf"
    else
      echo -en "\e[0;35mBackup Server: \e[0m" | sed "s/^/\t/g"
      echo ${ombs_server}
      echo ""
      echo -e "\e[0;35mBackup Schedule:\e[0m" | sed "s/^/\t/g"
      ssh ${ombs_server} -o StrictHostKeyChecking=no "/usr/openv/netbackup/bin/admincmd/bppllist ${ombs_policy_name} -U | egrep 'Daily |day |SCHEDCALDAYOWEEK'" | sed "s/^/\t/g"
      echo ""
      echo -e "\e[0;35mRecent Successful Backups Taken:\e[0m" | sed "s/^/\t/g"
      ms_backup_hostname=$(cat /usr/openv/netbackup/bp.conf | grep "CLIENT_NAME" | awk '{print $NF}')
      ssh ${ombs_server} -o StrictHostKeyChecking=no "/ericsson/ombss_enm_backup/bin/manage_backup_images.bsh -M ${ms_backup_hostname} -s" | sed "s/^/\t\t/g"
      echo ""
      echo -e "\e[0;35mList of all Backups currently available for ${ms_backup_hostname}:\e[0m" | sed "s/^/\t/g"
      ssh ${ombs_server} -o StrictHostKeyChecking=no "/ericsson/ombss_enm_backup/bin/manage_backup_images.bsh -M ${ms_backup_hostname} -l | egrep -v "\""ieatrcxb|ieatsfsx|ieatnas"\"" " | sed "s/^/\t\t/g"
      echo ""
      echo -e "\e[0;35mOther ENM servers sharing this OMBS Server:\e[0m" | sed "s/^/\t/g"
      ssh ${ombs_server} -o StrictHostKeyChecking=no "/usr/openv/netbackup/bin/admincmd/bppllist" | grep "ENM_SCHEDULED" | sed "s/^/\t\t/g"
      echo ""
      echo -e "\e[0;35mInfo on most recent Backup:\e[0m" | sed "s/^/\t/g"
      ssh ${ombs_server} -o StrictHostKeyChecking=no "/ericsson/jobs_parser.bsh -k ${ombs_keyword}" | sed "s/^/\t/g"
      echo ""
      echo -e "\e[0;35mMost recent errors or logs from last backup from /opt/ericsson/itpf/bur/log/brs/brs.log:\e[0m" | sed "s/^/\t/g"
      if [[ $(egrep -ri "ERROR|fail" /opt/ericsson/itpf/bur/log/brs/brs.log.1) != "" ]]; then
        egrep -ri "ERROR|fail" -A5 /opt/ericsson/itpf/bur/log/brs/brs.log.1 | tail -10
      else
        tail -10 /opt/ericsson/itpf/bur/log/brs/brs.log.1 | sed "s/^/\t/g"
      fi
      echo ""
      echo -e "\e[0;35mMost recent backup log from /opt/ericsson/itpf/bur/log/brs/backup:\e[0m" | sed "s/^/\t/g"
      if [ -s /opt/ericsson/itpf/bur/log/brs/backup/${backup_log} ]; then
        cat /opt/ericsson/itpf/bur/log/brs/backup/${backup_log} | tail -25 | sed "s/^/\t/g"
      else
        echo "No entries for today" | sed "s/^/\t\t/g"
      fi
      #List BUR Model File Systems
      #su - brsadm -c "/opt/ericsson/itpf/bur/bin/bos --operation list_model_file_systems"
      #BUR Health Check
      #su - brsadm -c "/opt/ericsson/itpf/bur/bin/bos --operation health_check"

      echo ""
      echo -e "\e[0;35mMost recent errors or logs for today from /opt/ericsson/itpf/bur/log/bos/bos.log*:\e[0m" | sed "s/^/\t/g"
      if [[ $(egrep -ri "ERROR|fail" /opt/ericsson/itpf/bur/log/bos/bos.log* | grep $(date +%Y-%m-%d)) == "" ]]; then
        tail -100 /opt/ericsson/itpf/bur/log/bos/bos.log | egrep -v "BOSsnapshotOperation" | tail -10 | sed "s/^/\t\t/g"
      else
        egrep -ri "ERROR|fail" /opt/ericsson/itpf/bur/log/bos/bos.log* | grep $(date +%Y-%m-%d) -A5 | tail -20 | sed "s/^/\t\t/g"

      fi
    fi

  else
    echo -e "\e[0;32mBackup Info:\e[0m"
    echo -e "\e[0;32m============\e[0m"
    echo -e "\e[0;35mSummary of recent Backups on VNF-LAF: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i /var/tmp/enm_keypair.pem cloud-user@${vnflaf_internal_ip}" "exec sudo -i" cat /ericsson/3pp/jboss/standalone/log/server.log* | egrep "MeasureRateUtil|Backup tag is|Backup size|Volume size" | sed "s/^/\t/g"
  fi
}

vcs_info() {
  if [ ${env_type} = physical ]; then
    echo
    echo -e "\e[0;32mVCS Events - Monitor Timeouts & Restarts:\e[0m"
    echo -e "\e[0;32m=========================================\e[0m"
    #Get all monitor timeouts for the day
    for i in $(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}'); do ${sshvm} $i-1 "grep $(date +%Y/%m/%d) /var/VRTSvcs/log/engine_A.log | egrep  'monitor procedure did not complete within the expected time|has reported unexpected OFFLINE' | grep -oP 'Res(.*)' | sort | uniq -c | sort -nrk1 >> /ericsson/enm/dumps/vcs_timeouts_tmp_$i.log"; done &>/dev/null
    #Get all restarts for the day
    for i in $(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}'); do ${sshvm} $i-1 "grep $(date +%Y/%m/%d) /var/VRTSvcs/log/engine_A.log | egrep  'Agent is restarting' | grep -oP 'Res(.*)' | sort | uniq -c | sort -nrk1 >> /ericsson/enm/dumps/vcs_restarts_tmp_$i.log"; done &>/dev/null

    echo -e "\e[0;35mVCS Monitor Timeout & Offline Events:\e[0m" | sed "s/^/\t/g"

    for i in $(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}'); do
      echo -e "\e[1;36m$i Cluster - Monitor Timeout/Offline Events:\e[0m" | sed "s/^/\t\t/g"
      if [ -s /ericsson/enm/dumps/vcs_timeouts_tmp_$i.log ]; then
        cat /ericsson/enm/dumps/vcs_timeouts_tmp_$i.log | sed "s/^/\t\t/g"
      else
        echo -e "\e[1;37mNone\e[0m" | sed "s/^/\t\t\t/g"
      fi
      echo ""
    done

    echo -e "\e[0;35mVCS Restarts Events:\e[0m" | sed "s/^/\t/g"

    for i in $(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}'); do
      echo -e "\e[1;36m$i Cluster - Restart Events:\e[0m" | sed "s/^/\t\t/g"
      if [ -s /ericsson/enm/dumps/vcs_restarts_tmp_$i.log ]; then
        cat /ericsson/enm/dumps/vcs_restarts_tmp_$i.log | sed "s/^/\t\t/g"
      else
        echo -e "\e[1;37mNone\e[0m" | sed "s/^/\t\t\t/g"
      fi
      echo ""
    done

    rm -rf /ericsson/enm/dumps/vcs_restarts_tmp_*.log
    rm -rf /ericsson/enm/dumps/vcs_timeouts_tmp_*.log
  fi
}

vcs_cluster_node_status() {
  if [ ${env_type} = physical ]; then
    echo
    echo -e "\e[0;32mStatus of each VCS node in each cluster: \e[0m"
    echo -e "\e[0;32m========================================\e[0m"
    for i in $(nodemappings all | awk -F "-" '{print $1}' | sort | uniq); do
      echo -e "\e[0;35m$i Cluster:\e[0m" >>${rv_dailychecks_tmp_file}
      echo -e "\e[0;35m============\e[0m" >>${rv_dailychecks_tmp_file}
      ${sshvm} ${i}-1 "hastatus -sum | egrep '^A|SYSTEM STATE|Frozen' >> ${rv_dailychecks_tmp_file}" &>/dev/null
      echo "" >>${rv_dailychecks_tmp_file}
    done
    read_rv_dailychecks_tmp
  fi
}

shm_info() {
  echo
  echo -e "\e[0;32mSHM Job Status for $(date +%b" "%d):\e[0m"
  echo -e "\e[0;32m==========================\e[0m"
  ${CLI_APP} 'shm status --all' | grep $(date +%d/%m/%Y) >${rv_dailychecks_tmp_file}
  echo ""
  echo -e "\e[1;34mTotal # of SHM Jobs up to $(date):\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | wc -l | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mSummary of SHM Job status:\e[0m" | sed "s/^/\t/g"
  for i in $(awk '{print $2}' ${rv_dailychecks_tmp_file} | sort | uniq); do
    for n in $(awk '{print $6}' ${rv_dailychecks_tmp_file} | sort | uniq); do
      for m in $(awk '{print $7}' ${rv_dailychecks_tmp_file} | sort | uniq); do
        echo -en '\t' $i" "
        echo -en '\t' $n
        echo -en '\t' $m" "
        echo -en '\t'
        cat ${rv_dailychecks_tmp_file} | grep -w $i | grep $n | grep -c $m
      done
      echo ""
    done
  done
  echo ""
  echo -e "\e[1;34mSHM System Cancelled Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "SYSTEM_CANCELLED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;34mFailed or Skipped SHM Backup Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "BACKUP" | egrep "FAILED|SKIPPED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;34mFailed or Skipped SHM Backup Housekeeping Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "BACKUP_HOUSEKEEPING" | egrep "FAILED|SKIPPED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;32mFailed or Skipped SHM Delete Backup Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "DELETEBACKUP" | egrep "FAILED|SKIPPED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;36mFailed or Skipped SHM Upgrade Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "UPGRADE" | egrep "FAILED|SKIPPED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;36mFailed or Skipped SHM Delete Upgrade Package Jobs:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | egrep -w "DELETE_UPGRADEPACKAGE" | egrep "FAILED|SKIPPED" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[1;35mSHM Jobs with 80 or more nodes:\e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk '$4 > 79 {print}' | sed "s/^/\t/g"
  echo ""
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

fm_alarm_status_db_overview() {
  echo
  echo -e "\e[0;32mSummary of Alarm Info: \e[0m"
  echo -e "\e[0;32m======================\e[0m"

  if [ ${dps_persistence_provider} = versant ]; then
    echo -e "\e[0;35mSummary of Alarm statuses in versant db:\e[0m" | sed "s/^/\t/g"
    ${sshvm} db1-service "/ericsson/versant/bin/db2tty -u versant -p shroot -D dps_integration -i ns_FM.Pt_OpenAlarm > /ericsson/enm/dumps/rv_dailychecks_tmp_file.log" &>/dev/null
    sleep 20
    for i in $(grep at_alarmState ${rv_dailychecks_tmp_file} | grep -v char | sort | uniq | awk '{print $3}' | cut -d= -f2); do
      echo -n "Total ${i} alarms: " | sed "s/^/\t/g"
      grep -c ${i} ${rv_dailychecks_tmp_file}
      grep ${i} ${rv_dailychecks_tmp_file} -A35 | grep "at_presentSeverity" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
      echo
    done
  fi

  echo -e "\e[0;35mVolume of inconsistent (Count of Acknowledged & Cleared) alarms built up in the system: \e[0m" | sed "s/^/\t/g"
  ${CLI_APP} 'alarm get * --cleared --ack --count' | sed "s/^/\t/g"
}

sso_active_count() {
  echo
  echo -e "\e[0;32mCurrent number of SSO Active Users: \e[0m"
  echo -e "\e[0;32m===================================\e[0m"
  for i in $(grep svc.*sso /etc/hosts | awk '{print $2}' | sort); do
    echo -en "\e[0;35m${i}: \e[0m" | sed "s/^/\t/g"
    ${sshvm} $i '/opt/ericsson/sso/heimdallr/opends/bin/ldapsearch --dontWrap --port 10389 --bindDN "cn=Directory Manager" -w `cat /opt/ericsson/sso/config/config-access.bin` -b ou=famrecords,ou=openam-session,ou=tokens,dc=opensso,dc=java,dc=net coreTokenType=SESSION coreTokenUserId coreTokenExpirationDate | grep "dn:" | wc -l' >${rv_dailychecks_tmp_file}
    cat ${rv_dailychecks_tmp_file} | tail -3 | head -1
    truncate -s 0 ${rv_dailychecks_tmp_file}
    echo
  done
}

sso_replication_state() {
  echo
  echo -e "\e[0;32mSSO Replication State: \e[0m"
  echo -e "\e[0;32m======================\e[0m"
  for i in $(grep svc.*sso /etc/hosts | awk '{print $2}' | sort | head -1); do
    echo -e "\e[0;35mChecking from ${i}: \e[0m" | sed "s/^/\t/g"
    ${sshvm} $i "/opt/ericsson/sso/heimdallr/opends/bin/dsreplication status --adminUID admin --adminPassword c0nf1gh31md477R --hostname localhost --port 4445 --trustAll > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
  done
}

elasticsearch_rejected_index_count() {
  echo
  echo -e "\e[0;32mCount of Elastic Search rejected indexes:\e[0m"
  echo -e "\e[0;32m=========================================\e[0m"
  curl -XGET "elasticsearch:9200/_cat/thread_pool?v&h=host,ip,index.active,index.queue,index.rejected" | sed "s/^/\t/g"
}

kpi_overview() {
  echo
  echo -e "\e[0;32mOverview of Active Node & Cell Level KPIs:\e[0m"
  echo -e "\e[0;32m==========================================\e[0m"
  echo -e "\e[1;35mKPISERV Instance\t numberOf_activeNodeLevelKPI \t avgNumberOfNodes_activeNodeLevelKPI \t numberOf_activeCellLevelKPI \t avgNumberOfNodes_activeCellLevelKPI\e[0m" | sed 's/^/\t/g'
  for i in $(ls /var/ericsson/ddc_data/ | grep kpiserv); do
    echo -ne "$i\t\t\t"
    echo -n $(grep KpiSpecificationServiceMetric /var/ericsson/ddc_data/$i/$(date +%d%m%y)/instr.txt | tail -1 | awk '{print $(NF)}')
    echo -ne "\t\t\t\t"
    echo -n $(grep KpiSpecificationServiceMetric /var/ericsson/ddc_data/$i/$(date +%d%m%y)/instr.txt | tail -1 | awk '{print $(NF-57)}')
    echo -ne "\t\t\t\t\t"
    echo -n $(grep KpiSpecificationServiceMetric /var/ericsson/ddc_data/$i/$(date +%d%m%y)/instr.txt | tail -1 | awk '{print $(NF-1)}')
    echo -ne "\t\t\t\t"
    grep KpiSpecificationServiceMetric /var/ericsson/ddc_data/$i/$(date +%d%m%y)/instr.txt | tail -1 | awk '{print $(NF-58)}'
  done | sed 's/^/\t/g'
}

db_vxlist_vol() {
  echo
  echo -e "\e[0;32mDisplay Consolidated storage foundation information - vxlist:\e[0m"
  echo -e "\e[0;32m=============================================================\e[0m"
  for i in $(${VCS} --groups -c db_cluster | grep "OK" | awk '{print $3}' | sort | uniq); do
    echo -e "\e[1;35mDB NODE: $i\e[0m" >>${rv_dailychecks_tmp_file}
    echo -e "\e[1;35m=======================\e[0m" >>${rv_dailychecks_tmp_file}
    echo "" >>${rv_dailychecks_tmp_file}
    ${sshvm} $i "/opt/VRTSsfmh/adm/dclisetup.sh;vxlist >> ${rv_dailychecks_tmp_file}" &>/dev/null
    echo -e "\r\r\r" >>${rv_dailychecks_tmp_file}
  done
  read_rv_dailychecks_tmp
}

san_healthcheck() {
  echo
  echo -e "\e[0;32mSAN Healthcheck:\e[0m"
  echo -e "\e[0;32m================\e[0m"
  ${ENM_HEALTHCHECK} --action storagepool_healthcheck | sed 's/^/\t/g'
}

amos_housekeeping() {
  echo
  echo -e "\e[0;32mCheck if AMOS Housekeeping is applied:\e[0m"
  echo -e "\e[0;32m======================================\e[0m"
  echo -e "\e[0;35mChecking on scp-1-scripting: \e[0m" | sed "s/^/\t/g"
  ${sshvm} scp-1-scripting "cat /etc/cron.d/AMOS_LOGS_CRONJOB > /ericsson/enm/dumps/rv_dailychecks_tmp_file.log" &>/dev/null
  read_rv_dailychecks_tmp
  echo
}

amos_temp_users() {
  echo
  echo -e "\e[0;32mCount of Temporary AMOS users in Postgres:\e[0m"
  echo -e "\e[0;32m==========================================\e[0m"
  ${sshvm} postgresql01 "export PGPASSWORD=P0stgreSQL11;/opt/rh/postgresql92/root/usr/bin/psql -h postgresql01 -U postgres -d idenmgmt -c "\""select status, count(*) from postgre_user where email = 'temporary@amos.com' group by status"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
}

versant_overview() {
  if [ ${dps_persistence_provider} = versant ]; then
    echo
    echo -e "\e[0;32mOverview of Versant Status:\e[0m"
    echo -e "\e[0;32m===========================\e[0m"
    echo -e "\e[0;35mDB Mode & status: \e[0m" | sed "s/^/\t/g"
    ${sshvm} db1-service "su - versant -c "\""/ericsson/versant/dbscripts/health_check/versant_admin.py -s"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
    echo ""
    echo -e "\e[0;35mPercentage of free extents in DB: \e[0m" | sed "s/^/\t/g"
    ${sshvm} db1-service "su - versant -c "\""/ericsson/versant/dbscripts/health_check/versant_admin.py -m|grep 'Percentage of free extents in DB'"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
    echo ""
    echo -e "\e[0;35mDead & Long Running Transactions: \e[0m" | sed "s/^/\t/g"
    ${sshvm} db1-service "su - versant -c "\""/ericsson/versant/dbscripts/health_check/versant_admin.py -t"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
    echo ""
    read_rv_dailychecks_tmp
  fi
}

stkpi_cm_change() {
  if [ -e /ericsson/enm/dumps/KPI_LOGFILES/stkpi_CM_Change_01*$(date +%y%m%d).log* ]; then
    echo
    echo -e "\e[0;32mSummary of CM Change STKPI runs today:\e[0m"
    echo -e "\e[0;32m==========================================\e[0m"
    cat /ericsson/enm/dumps/KPI_LOGFILES/stkpi_CM_Change_01*$(date +%y%m%d).log | grep Takes | awk {'print "Time: " $17 "\t  "  $11": " $10"\tTime taken: " $3}' | sed 's/^/\t/g'
  fi
}

stkpi_cm_sync_mo_count() {
  if [ -e /etc/cron.d/stkpi_CM_Synch_01 ]; then
    echo
    echo -e "\e[0;32mNumber of MOs on node used for CM Sync_01 STKPI:\e[0m"
    echo -e "\e[0;32m================================================\e[0m"
    echo -en "\e[0;35mERBS Node:\t\t\e[0m" | sed "s/^/\t/g"
    echo ${stkpi_erbs}
    echo -en "\e[0;35mNetsim Node:\t\t\e[0m" | sed "s/^/\t/g"
    echo ${stkpi_netsim}
    echo -en "\e[0;35mNetsim Simulation:\t\e[0m" | sed "s/^/\t/g"
    echo ${stkpi_sim}
    echo -en "\e[0;35mNumber of MOs:\t\e[0m" | sed "s/^/\t/g"
    ssh netsim@${stkpi_netsim} "echo "\""dumpmotree:moid=1;"\"" |/netsim/inst/netsim_pipe -sim ${stkpi_sim} -ne ${stkpi_erbs}" | grep "Number of MOs" | awk '{print $NF}' | sed 's/^/\t/g'
  fi
}

eniq_integration_status() {
  echo
  echo -e "\e[0;32mENIQ Integration Status: \e[0m"
  echo -e "\e[0;32m========================\e[0m"
  echo -e "\e[0;35mPIB Parameter Settings:\t\t\e[0m" | sed "s/^/\t/g"
  /opt/ericsson/ENM_ENIQ_Integration/eniq_enm_integration.py showPIBvalues | egrep -v "Checking pmserv and impexpserv are available|Reading PIB Values|^$" | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mIntegrated ENIQ details:\t\t\e[0m" | sed "s/^/\t/g"
  /opt/ericsson/ENM_ENIQ_Integration/eniq_enm_integration.py list_eniqs | egrep -v "Checking pmserv and impexpserv are available|Listing down the integrated Eniq system" | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mENIQ Daily Topology & Historical CM Export status & Timings:\t\t\e[0m" | sed "s/^/\t/g"
  /opt/ericsson/ENM_ENIQ_Integration/eniq_enm_integration.py showExportTimes | egrep -v "Checking pmserv and impexpserv are available|^$" | sed "s/^/\t/g"
}

ldap_overview() {
  echo
  echo -e "\e[0;32mLDAP Overview - LTE Baseband RadioNodes:\e[0m"
  echo -e "\e[0;32m========================================\e[0m"
  echo -en "# of LTE RadioNodes:\t\t\t\t" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit get *dg2* --count' | tail -1
  echo
  echo -en "# nodes with LDAP AdminState UNLOCKED:\t\t" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit get *dg2* LdapAuthenticationMethod.administrativeState==UNLOCKED -count' | tail -1
  echo -en "# nodes with LDAP AdminState LOCKED:\t\t" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit get *dg2* LdapAuthenticationMethod.administrativeState==LOCKED -count' | tail -1
  echo
  echo -e "Breakdown of secure name settings for RadioNodes:\t\t" | sed "s/^/\t/g"
  ${CLI_APP} 'cmedit get *dg2* NetworkElementSecurity.secureUserName -t' | awk '{print $NF}' | egrep -vi "secur|instance" | cut -c1-9 | sort | uniq -c | sort -nrk1 | sed "s/^/\t\t\t\t\t\t/g"
  echo
  echo -e "\e[0;36mOther LDAP Configuration Settings:\e[0m" | sed "s/^/\t/g"
  echo -en "# nodes using LDAP IPv4 IP Address:\t" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* Ldap.ldapIpAddress=="\""${svc_CM_vip_ipaddress}"\"" --count" | tail -1
  echo -en "# nodes using LDAP IPv6 IP Address:\t" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* Ldap.ldapIpAddress=="\""${svc_CM_vip_ipv6address}"\"" --count" | tail -1
  echo
  echo -en "# nodes with Ldap.profileFilter=ERICSSON_FILTER:\t" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* Ldap.profileFilter==ERICSSON_FILTER --count" | tail -1 | sed "s/^/\t/g"

  echo -en "# nodes with ldapApplicationUserName=ldapApplicationUser:" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* NetworkElementSecurity.ldapApplicationUserName==ldapApplicationUser -count" | tail -1 | sed "s/^/\t/g"

  echo -en "# nodes with Ldap.serverPort=1636:\t\t\t" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* Ldap.serverPort==1636 -cn" | tail -1 | sed "s/^/\t/g"

  echo -en "# nodes with Ldap.tlsMode=LDAPS:\t\t\t" | sed "s/^/\t\t/g"
  ${CLI_APP} "cmedit get *dg2* Ldap.tlsMode==LDAPS -cn" | tail -1 | sed "s/^/\t/g"
  echo
  echo -e "\e[0;36mLDAP bindDn Settings:\e[0m" | sed "s/^/\t/g"

  num_ldap_bindDn=$(${CLI_APP} 'cmedit get * Ldap.bindDn -t -ne=RadioNode' | egrep -v "LdapAuthenticationMethod|bindDn|instance" | awk '{print $NF}' | sort | uniq | wc -l)
  if [ ${num_ldap_bindDn} -lt 20 ]; then
    for i in $(${CLI_APP} 'cmedit get * Ldap.bindDn -t -ne=RadioNode' | egrep -v "LdapAuthenticationMethod|bindDn|instance" | awk '{print $NF}' | sort | uniq); do
      echo $i | sed "s/^/\t/g"
      ${CLI_APP} "cmedit get * Ldap.bindDn=="\""${i}"\"" -t -ne=RadioNode" | grep LTE | awk -F "ERBS" '{print $1}' | sort | uniq -c | sed "s/^/\t\t/g"
    done
  else
    echo "Too many different ldap.binDn configurations exist & thus will not be listed here." | sed "s/^/\t/g"
  fi
}

cmsync_setup_notifications() {
  echo
  echo -e "\e[0;32mCMSync_Setup planned daily notification levels:\e[0m"
  echo -e "\e[0;32m===============================================\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "egrep 'Total cell values for|ranCell|Total Cell Count|Estimated daily notifications|Profile Node Allocation|Total notifications to be generated|INFO.*$' /var/log/enmutils/daemon/cmsync_setup.log | egrep "\""$(date +%Y-%m-%d)|Total notifications to be generated "\"" | egrep -v 'Profile Notification Values|\[\]|\[\[|MO instances|with file|instance|WRITE DATA|Updated mediation dict' | tail -32" | sed "s/^/\t/g"
  else
    egrep 'Total cell values for|ranCell|Total Cell Count|Estimated daily notifications|Profile Node Allocation|Total notifications to be generated|INFO.*$' /var/log/enmutils/daemon/cmsync_setup.log | egrep "$(date +%Y-%m-%d)|Total notifications to be generated" | egrep -v 'Profile Notification Values|\[\]|\[\[|MO instances|with file|instance|WRITE DATA|Updated mediation dict' | tail -32 | sed "s/^/\t/g"
  fi
}

netconf_session() {
  echo
  echo -e "\e[0;32mMSCMCE NetConf Session Summary:\e[0m"
  echo -e "\e[0;32m===============================\e[0m"

  echo -en "\e[0;35mMSCMCE comecim_cm_notification_buffer_time_to_live parameter value:\t\e[0m" | sed "s/^/\t/g"
  if [ ${env_type} = physical ]; then
    /ericsson/pib-scripts/etc/config.py read --app_server_address=svc-3-mscmce:8080 --name=comecim_cm_notification_buffer_time_to_live
  else
    ssh -tt -i ${keypair} cloud-user@${EMP} "exec sudo -i" /ericsson/pib-scripts/etc/config.py read --app_server_address=svc-2-mscmce:8080 --name=comecim_cm_notification_buffer_time_to_live
  fi
  echo

  for i in $(grep mscmce /etc/hosts | awk '{print $2}' | sort); do
    echo -en "${i}:\t" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
    ${sshvm} $i '/opt/ericsson/jboss/modules/com/ericsson/oss/mediation/adapter/netconf/jca/scripts/debugger.sh showNumOfNetconfSessions | grep '\''Netconf Sessions Managed'\'' >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log;' &>/dev/null
  done
  cat /ericsson/enm/dumps/rv_dailychecks_tmp_file.log | sed "s/^/\t/g"
  >/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
  echo
  echo -e "\e[0;32mNumber & Date/Hour when connections were created\n================================================\e[0m" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
  for i in $(grep mscmce /etc/hosts | awk '{print $2}' | sort); do
    echo -e "\n${i}:\t" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
    ${sshvm} $i "export TABLE_FIELDS='CreationTime,14'; /opt/ericsson/jboss/modules/com/ericsson/oss/mediation/adapter/netconf/jca/scripts/debugger.sh showNetconfSessionRegistry | awk '{print $3}' | grep $(date +%Y) | sort | uniq -c | sed "\""s/^/\t/g"\"" >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log" &>/dev/null
  done
  cat /ericsson/enm/dumps/rv_dailychecks_tmp_file.log | sed "s/^/\t/g"
  >/ericsson/enm/dumps/rv_dailychecks_tmp_file.log

  #sshvm $i 'TABLE_FIELDS="Keyhashcode,15;CreationTime,25;ServiceKey,5;SubscriberKey,4;UserKey,50;XAProvider,5;Username,15;IpAddress,39;Port,4;Prot,4;SessionMode,15;SessionType,15;SessTypeValue,3;Number,2;Connected,11;EntryCreationTime,25;LockInfo,9;LockedThreads,25;RunningThreads,5" /opt/ericsson/jboss/modules/com/ericsson/oss/mediation/adapter/netconf/jca/scripts/debugger.sh showNetconfSessionRegistry

  #[root@svc-3-mscmce ~]# /opt/ericsson/jboss/modules/com/ericsson/oss/mediation/adapter/netconf/jca/scripts/debugger.sh -h
  #Use 'debugger.sh <option>' or 'debugger.sh <option1> <option2> ... <optionN>>'
  #Options:
  #          help                             : to show this help menu
  #          showNumOfNetconfSessions         : to show the number of connections managed by Netconf RAR
  #          showNetconfSessionRegistryFields : to show Netconf Session Registry fields
  #          showNetconfSessionRegistry       : to show all connections managed by Netconf RAR. Define TABLE_FIELDS to customize the dump.
  #          showSessionsInfo                 : to show the LONG_LIFE connections managed by Netconf RAR, the binded subscribers and Periodic Tasks activated
  #          showConnectionsRegistry          : to show the LONG_LIFE connections managed by Netconf RAR
  #          showConnectionsRegistryFields    : to show Session Manager Registry fields
  #          showSubscribersRegistry          : to show all the subscribers registered to Netconf RAR
  #          showSubscribersRegistryFields    : to show Subscriber Registry fields
  #          showPeriodicTasksRegistry        : to show Periodic Tasks currently activated
  #          showPeriodicTasksRegistryFields  : to show Periodic Tasks Registry fields
  #NOTE:
  #          Use "...Fields" command to see the available fields
  #          The fieds must be provided with name and length. Using 0 as length the field name length is used by default
  #          e.g TABLE_FIELDS="ServiceKey,50;UserKey,0;SessionMode,0" debugger.sh showNetconfSessionRegistry

}

neo4j_info() {
  >/ericsson/enm/dumps/neo_admin.log

  #                if [ ${env_type} == "cloud" ]; then

  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mGeneral NEO4J Info: \e[0m"
    echo -e "\e[0;32m===================\e[0m"
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py version" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py uptime" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py filesystem" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py metadata" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py cluster" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py errors | tail" >> /tmp/neo_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'echo "/opt/ericsson/neo4j/util/dps_db_admin.py warns | tail" >> /tmp/neo_admin.bsh' &> /dev/null

    #${sshvm} ${neo_instance} 'chmod 755 /tmp/dps_db_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'sudo mv /tmp/dps_db_admin.bsh /ericsson/enm/dumps/dps_db_admin.bsh' &> /dev/null
    #${sshvm} ${neo_instance} 'sudo -i /ericsson/enm/dumps/dps_db_admin.bsh' | sed "s/^/\t/g"

    echo -en "\e[0;35mNeo4j Version\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py version | egrep -v '^$' | paste - - >> /ericsson/enm/dumps/neo_admin.log" &>/dev/null
    echo -en "\e[0;35mNeo4j Uptime\t \e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py uptime | egrep -v '^$' | paste - - >> /ericsson/enm/dumps/neo_admin.log" &>/dev/null
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -e "\e[0;35mNeo4j File System Usage\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py filesystem" | grep filesystem -A11 >>/ericsson/enm/dumps/neo_admin.log
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -en "\e[0;35mNeo4j Lag Times\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py lag >> /ericsson/enm/dumps/neo_admin.log" &>/dev/null
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -e "\e[0;35mNeo4j Metadata\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py metadata" | grep metadata -A20 >>/ericsson/enm/dumps/neo_admin.log
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -e "\e[0;35mNeo4j Cluster Overview\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py cluster" | grep cluster -A15 >>/ericsson/enm/dumps/neo_admin.log
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -e "\n\e[0;35mNeo4j Recent Error Messages\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py errors | head -20 | grep -v "Press" >> /ericsson/enm/dumps/neo_admin.log" &>/dev/null
    echo >>/ericsson/enm/dumps/neo_admin.log
    echo -e "\n\e[0;35mNeo4j Recent Warning Messages\e[0m" >>/ericsson/enm/dumps/neo_admin.log
    ${sshvm} ${neo_leader} "/opt/ericsson/neo4j/util/dps_db_admin.py warns | head -20 | grep -v "Press" >> /ericsson/enm/dumps/neo_admin.log" &>/dev/null

    #${sshvm} ${neo_leader} 'sudo mv /tmp/neo_admin.log /ericsson/enm/dumps/neo_admin.log' &> /dev/null
    sleep 15
    cat /ericsson/enm/dumps/neo_admin.log | sed "s/^/\t/g"
    >/ericsson/enm/dumps/neo_admin.log
  fi
}

neo4j_table() {
  if [ ${dps_persistence_provider} = "neo4j" ]; then
    echo
    echo -e "\e[0;32mNEO4J Overview of Instances on each DB Node: \e[0m"
    echo -e "\e[0;32m============================================\e[0m"

    ${sshvm} ${neo_instance} "/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action cluster_overview >> ${rv_dailychecks_tmp_file}" &>/dev/null
    printf "|===============================================================================|\n" | sed "s/^/\t/g"
    printf "| $blue%-12s | %-5s | %-14s | %-8s | %-9s | %-7s | \n" "DB HOSTNAME" "DB NODE" "DB INTERNAL IP" "NEO ROLE" "MEMBER_ID" "NEO INSTANCE" | sed "s/^/\t/g"
    printf "|==============|=========|================|==========|===========|==============|\n" | sed "s/^/\t/g"

    for i in $(/opt/ericsson/enminst/bin/vcs.bsh --groups | grep neo | awk '{print $3}' | sort); do
      printf "| %12s " ${i} | sed "s/^/\t/g"
      printf "| %5s   " $(nodemappings db | grep $i | awk -F ":" '{print $1}')
      db_number=$(nodemappings db | grep $i | awk -F ":" '{print $1}' | awk -F "-" '{print $2}')
      db_internal_ip=$(grep db_node${db_number}_IP_internal /software/autoDeploy/MASTER_siteEngineering.txt | awk -F "=" '{print $2}')
      printf "| %14s " ${db_internal_ip}
      if [ ${neo4j_cluster_type} = single ]; then
        printf "| %8s " $(/opt/ericsson/enminst/bin/vcs.bsh --groups | grep neo.*${i} | awk '{print $6}')
        printf "| %9s " "N/A"
      else
        printf "| %8s " $(grep ${db_internal_ip} ${rv_dailychecks_tmp_file} | awk -F ":" '{print $2}')
        printf "| %9s " $(grep ${db_internal_ip} ${rv_dailychecks_tmp_file} | awk -F ":" '{print $3}' | awk -F "-" '{print $1}')
      fi
      printf "| %11s  |\n"
    done
    printf "|===============================================================================|\n" | sed "s/^/\t/g"

    >${rv_dailychecks_tmp_file}
  fi
}

neo4j_status() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mCurrent NEO4J Status at $(date): \e[0m"
    echo -e "\e[0;32m=====================================================\e[0m"
    echo -e "\e[0;35mDPS Provider & Neo4j mode (Single or Causal Cluster): \e[0m" | sed "s/^/\t/g"
    egrep "dps_persistence_provider" /ericsson/tor/data/global.properties | sed "s/^/\t/g"
    egrep "neo4j_cluster" /ericsson/tor/data/global.properties | sed "s/^/\t/g"

    if [ $(egrep "neo4j_cluster" /ericsson/tor/data/global.properties | awk -F "=" '{print $2}') == "causal" ]; then
      echo
      for i in $(grep neo4j /etc/hosts | awk '{print $2}' | sort); do
        echo -e "\e[0;35m${i}: cypher-shell\e[0m \e[0;36m\"CALL dbms.cluster.overview();\"\e[0m\e[0;35m query:\e[0m" >>${rv_dailychecks_tmp_file}
        ${sshvm} $i "/ericsson/3pp/neo4j/bin/cypher-shell -u neo4j -p Neo4jadmin123 -a bolt://${i}:7687 'CALL dbms.cluster.overview() YIELD id, addresses, role;' >> ${rv_dailychecks_tmp_file}" &>/dev/null
        echo -e "\n\e[0;35m${i}: \e[0m\e[0;36m\"/opt/ericsson/neo4j/util/dps_db_admin.py cluster\"\e[0m\e[0;35m query: \e[0m" >>${rv_dailychecks_tmp_file}
        ${sshvm} $i "/opt/ericsson/neo4j/util/dps_db_admin.py cluster >> ${rv_dailychecks_tmp_file}" &>/dev/null
      done
      read_rv_dailychecks_tmp
    fi
  fi
}

neo_leader_moves() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mRecent NEO4j Leader changes: \e[0m"
    echo -e "\e[0;32m============================\e[0m"
    for i in {1..3}; do
      ${sshvm} neo4j${i} "egrep 'Moving to LEADER state at term|Leader changed from MemberId|Stopping, reason: Database is stopped' /ericsson/neo4j_data/logs/debug.log* | head -20" | grep -oP $(date +%Y).* | grep -v lms >>/var/tmp/neo4j_leader
      sed -i "s/^20/NEO4J${i}: 20/g" /var/tmp/neo4j_leader
    done

    cat /var/tmp/neo4j_leader | grep INFO | sort -k2 | awk '{$5=""; print $0;}' | sed "s/^/\t/g"
    echo
    cat /var/tmp/neo4j_leader | grep "I am MemberId" | awk '{print $1," ",$15}' | sed "s/^/\t/g" | sort | uniq
    rm -rf /var/tmp/neo4j_leader
  fi
}

neo4j_GC() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mRecent NEO4J Garbage Collection: \e[0m"
    echo -e "\e[0;32m================================\e[0m"
    for i in {1..3}; do
      echo "#######neo4j${i}##########" | sed "s/^/\t/g"
      ${sshvm} neo4j${i} "egrep GC --colour /ericsson/neo4j_data/logs/debug.log | grep -v DiagnosticsManager" | tail -5 | sed "s/^/\t/g"
    done
  fi
}

neo4j_overview_trans() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mBreakdown of Neo4j Transactions: \e[0m"
    echo -e "\e[0;32m================================\e[0m"

    echo -e "\e[0;35mNumber of Neo4j transactions per VM that are > 15 secs:\e[0m" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
    ${sshvm} ${neo_leader} "grep -oP 'client\/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /ericsson/neo4j_data/logs/query.log* | grep -oP 'client.*' |sort | uniq -c | sort -nrk1 | head -10 >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log" &>/dev/null

    echo -e "\n===================================================" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log

    for i in {1..3}; do
      echo -en "# Queries >5sec on NEO4J${i} today:\t" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
      ${sshvm} neo4j${i} 'cat /ericsson/neo4j_data/logs/query.log* | grep -c $(date "+%Y-%m-%d") >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log' &>/dev/null
      echo -en "# Queries <10secs on NEO4J${i} today:\t" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
      ${sshvm} neo4j${i} 'cat /ericsson/neo4j_data/logs/query.log* | grep $(date "+%Y-%m-%d") | awk '\''$4 < 10000 {print $0}'\'' |wc -l >> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log' &>/dev/null
      echo -en "# Queries >10secs & <300secs on NEO4J${i} today:\t" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
      ${sshvm} neo4j${i} 'cat /ericsson/neo4j_data/logs/query.log* | grep $(date "+%Y-%m-%d") | awk '\''$4 > 10000 {print $0}'\'' | awk '\''$4 < 300000 {print $0}'\''|wc -l>> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log' &>/dev/null
      echo -en "# Queries >=300secs on NEO4J${i} today:\t" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
      ${sshvm} neo4j${i} 'cat /ericsson/neo4j_data/logs/query.log* | grep $(date "+%Y-%m-%d") | awk '\''$4 >= 300000 {print $0}'\'' |wc -l>> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log' &>/dev/null
      echo "===================================================" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
    done
    read_rv_dailychecks_tmp
    echo

    for i in {1..3}; do
      echo -e "\e[0;35mBreakdown of the top 30 queries >5secs run today on NEO4j${i}:\e[0m" | sed "s/^/\t/g" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
      ${sshvm} neo4j${i} 'cat /ericsson/neo4j_data/logs/query.log* | grep $(date "+%Y-%m-%d") | grep -oP "MATCH(.*?)WHERE|dps_user - CALL.*" | sort | uniq -c | sort -nrk1 | head -30>> /ericsson/enm/dumps/rv_dailychecks_tmp_file.log' &>/dev/null
      echo "" >>/ericsson/enm/dumps/rv_dailychecks_tmp_file.log
    done
    read_rv_dailychecks_tmp
  fi
}

neo4j_list_trans() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mList of current NEO4J Transactions: \e[0m"
    echo -e "\e[0;32m==================================\e[0m"
    echo -e "\e[0;35m| transactionId    | elapsedTimeMillis | username  | currentQuery  | requestUri    | clientAddress | status    |\e[0m" | sed "s/^/\t/g"
    ${sshvm} ${neo_leader} "/ericsson/3pp/neo4j/bin/cypher-shell -a  bolt://${neo_leader}:7687 "\""CALL dbms.listTransactions() YIELD transactionId, elapsedTimeMillis, username, currentQuery, requestUri, clientAddress, status;"\"" -u neo4j -p Neo4jadmin123" | grep -v "\-\-\-\-\-\-\-\-\-\-\-" | sort -nrk4 | sed 's/|/\n/g' | egrep -v "^$|^\t.*" | head -80 | sed "s/^/\t/g"
  fi
}

neo4j_list_queries() {
  if [ ${dps_persistence_provider} = neo4j ]; then
    echo
    echo -e "\e[0;32mTop 10 list of longest NEO4J Queries currently running: \e[0m"
    echo -e "\e[0;32m=======================================================\e[0m"
    echo
    #echo -e "\e[0;35m| Elapsed Time In Milliseconds          | Client Address            | Status            | Query    |\e[0m" | sed "s/^/\t/g"
    i=$(${sshvm} ${neo_instance} '/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action cluster_overview' | grep LEADER | awk -F ":" '{print $1}')
    #${sshvm} $i "/ericsson/3pp/neo4j/bin/cypher-shell -a  bolt://${i}:7687 "\""CALL dbms.listQueries() YIELD elapsedTimeMillis, clientAddress, status, query;"\"" -u neo4j -p Neo4jadmin123" |grep -v "\-\-\-\-\-\-\-\-\-\-\-" | sort -nrk2|sed 's/|/\n/g'|egrep -v "^$|^\t"|head -50 | sed "s/^/\t/g"
    ${sshvm} $i "/opt/ericsson/neo4j/util/dps_db_admin.py queries > ${rv_dailychecks_tmp_file}" &>/dev/null
    read_rv_dailychecks_tmp
  fi
}

pmic_pib_values() {
  echo
  echo -e "\e[0;32mPMIC File Retention & Recovery PIB Settings: \e[0m"
  echo -e "\e[0;32m============================================\e[0m"
  if [ ${env_type} = physical ]; then
    /ericsson/pib-scripts/etc/config.py read --all --app_server_address svc-4-pmserv:8080 | sed s/,/\\n/g | grep "GLOBAL___" | egrep -i "pmic.*retention|fileRecoveryHoursInfo" | awk -F "___" '{print $2}' | awk -F "\"" '{print $1}' >${rv_dailychecks_tmp_file}
    for i in $(cat ${rv_dailychecks_tmp_file}); do
      printf "%60s\t" ${i}
      /ericsson/pib-scripts/etc/config.py read --app_server_address svc-4-pmserv:8080 --name=${i} | sed "s/^/\t/g"
    done
  else
    ssh -tt -i ${keypair} cloud-user@$EMP "exec sudo -i" /ericsson/pib-scripts/etc/config.py read --all --app_server_address svc-4-pmserv:8080 | sed s/,/\\n/g | grep "GLOBAL___" | egrep -i "pmic.*retention|pmic.*delet|fileRecoveryHoursInfo" | awk -F "___" '{print $2}' | awk -F "\"" '{print $1}' >${rv_dailychecks_tmp_file}
    for i in $(cat ${rv_dailychecks_tmp_file}); do
      printf "%60s\t" ${i}
      ssh -tt -i ${keypair} cloud-user@$EMP "exec sudo -i" /ericsson/pib-scripts/etc/config.py read --app_server_address svc-4-pmserv:8080 --name=${i} | sed "s/^/\t/g"
    done
  fi
  >${rv_dailychecks_tmp_file}
}

amos_workload_checks() {
  if [ -e /tmp/amos_script.sh ]; then
    echo
    echo -e "\e[0;32mAMOS Workload Checks: \e[0m"
    echo -e "\e[0;32m=====================\e[0m"
    /tmp/amos_script.sh $(date +%Y-%m-%d) LMI_$(grep ddcDataUpload /var/log/cron | tail -1 | grep -oP "ENM[0-9]{3,4}") | sed "s/^/\t/g"
  else
    echo -e "\e[0;32mNote:\e[0m amos_script.sh & mysql files need to exist under /tmp/" | sed "s/^/\t/g"
  fi
}

amos_command_breakdown_per_profile() {
  echo
  echo -e "\e[0;32mBreakdown of AMOS commands sent & executed per profile: \e[0m"
  echo -e "\e[0;32m=======================================================\e[0m"
  echo -e "\e[0;35mNumber of commands sent & executed per AMOS profile on $(date +%Y-%m-%d): \e[0m" | sed "s/^/\t/g"
  for i in {01,02,03,04,08}; do
    echo "AMOS_${i}" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "zgrep $(date +%Y-%m-%d) /var/log/enmutils/daemon/amos_$i.log* | egrep 'Command sent|Executed command.*LTE'| grep -v 'Command sent: amos' | grep -oP 'Command sent|Executed command' | sort | uniq -c" | sed 's/^/\t/g'
    echo
  done
  echo -e "AMOS_05" | sed "s/^/\t/g"
  ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "zgrep $(date +%Y-%m-%d) /var/log/enmutils/daemon/amos_05.log* | grep -oP 'Full command .*mobatch|Executed command.*mobatch' | sort | uniq -c" | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mBreakdown of actual commands sent & executed per AMOS profile on $(date +%Y-%m-%d): \e[0m" | sed "s/^/\t/g"
  for i in {01,02,03,04,08}; do
    echo "AMOS_${i}" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "zgrep $(date +%Y-%m-%d) /var/log/enmutils/daemon/amos_$i.log* | egrep 'Command sent|Executed command.*LTE'| grep -v 'Command sent: amos' | grep -oP 'Command sent.*\(|Executed command.*in' | sort | uniq -c | sed 's/^/\t/g'"
    echo
  done
  echo -e "AMOS_05" | sed "s/^/\t/g"
  ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "zgrep $(date +%Y-%m-%d) /var/log/enmutils/daemon/amos_05.log* | egrep 'Full command .*mobatch|Executed command.*mobatch' | head -2" | sed "s/^/\t/g"
}

cmimport_05_stkpi() {
  echo
  echo -e "\e[0;32mCMIMPORT_05 STKPI Overview: \e[0m"
  echo -en "\e[0;32m===========================\e[0m"
  echo
  for i in $(grep impexpserv /etc/hosts | awk '{print $2}'); do
    ${sshvm} $i "grep "\""$(date +%Y-%m-%d).*executed.*import_05"\"" /ericsson/3pp/jboss/standalone/log/server.log* | cut -d, -f7,8,10,11,12,17 |tr -s ',' ' '|tr -s '=' ' ' >> ${rv_dailychecks_tmp_file}" &>/dev/null
  done
  if [ -e ${rv_dailychecks_tmp_file} ]; then
    while read line; do
      LINE=$(echo "$line" | awk '{print "Job: " $2 " | " $5 " " $6 " | " $9 " " $10" | STATUS: " $17" | TIME_TOOK: " $15"sec | MOs Updated: " $20 " | "}')
      LINE_1=$(echo "$line")
      n4=$(echo "$LINE_1" | awk '{print $20}')
      d4=$(echo "$LINE_1" | awk '{print $15}')
      r4=$(echo "scale=3;(${n4}/${d4})" | bc)
      printf "$LINE  " | sed "s/^/\t/g"
      echo -e "\e[0;34mResult: ${r4} MO/sec\e[0m"
    done <${rv_dailychecks_tmp_file}
  fi

  >${rv_dailychecks_tmp_file}
}

dps_events_summary() {
  echo
  echo -e "\e[0;32mDPS Events Summary at $(date): \e[0m"
  echo -e "\e[0;32m===================================================\e[0m"
  echo -e "\e[0;35mTotal number of DPS Events for today:\e[0m" | sed "s/^/\t/g"
  echo -en 'Total:\t' | sed "s/^/\t\t/g"
  zgrep -c 'Bucket Name' /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/data/$(date +%d%m%y)/TOR/clustered_data/jms/dps.events | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mNameSpace Hits (per Name) for today:\e[0m" | sed "s/^/\t/g"
  zgrep 'Bucket Name' /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/data/$(date +%d%m%y)/TOR/clustered_data/jms/dps.events | grep -oP 'Bucket Name:: Live; Namespace.*Name::' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mNameSpace Hits (per Type) for today:\e[0m" | sed "s/^/\t/g"
  zgrep 'Bucket Name' /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/data/$(date +%d%m%y)/TOR/clustered_data/jms/dps.events | grep -oP 'Bucket Name:: Live; Namespace.*Version:' | sort | uniq -c | sort -nrk1 | tail | sed "s/^/\t/g"
}

profiles_producing_errors() {
  echo
  echo -e "\e[0;32mNumber of Errors produced by Workload Profiles on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=========================================================\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no ${WORKLOAD_VM} "grep $(date +%Y-%m-%d) /var/log/enmutils/profiles.log| grep ERROR | cut -d "\"" "\"" -f6 |sort | uniq -c | sort -nrk1" | sed "s/^/\t/g"
  else
    grep $(date +%Y-%m-%d) /var/log/enmutils/profiles.log | grep ERROR | cut -d " " -f6 | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  fi
}

stkpi_crons() {
  echo
  echo -e "\e[0;32mCheck what STKPI crons are currently setup:\e[0m"
  echo -e "\e[0;32m===========================================\e[0m"
  for i in $(ls /etc/cron.d/stkpi_*); do
    echo $i | sed "s/^/\t/g"
    cat $i | sed "s/^/\t/g"
    echo
  done
}

stkpi_netex_01() {
  echo
  echo -e "\e[0;32mNetEx_01 STKPI:\e[0m"
  echo -e "\e[0;32m===============\e[0m"
  if [ ${env_type} = physical ]; then
    ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep 'Query returned' /var/log/enmutils/daemon/netex_03.log | grep $(date +%Y-%m-%d)" | sed "s/^/\t/g"
  else
    grep 'Query returned' /var/log/enmutils/daemon/netex_03.log | grep $(date +%Y-%m-%d) | sed "s/^/\t/g"
  fi
}

saved_searches() {
  echo
  echo -e "\e[0;32mList of Saved Searches:\e[0m"
  echo -e "\e[0;32m=======================\e[0m"
  ${CLI_APP} 'savedsearch list' | paste - - - - - | cut -f1-3 | sed "s/^/\t/g"
}

collections() {
  echo
  echo -e "\e[0;32mList of Collections:\e[0m"
  echo -e "\e[0;32m====================\e[0m"
  ${CLI_APP} 'collection list -t' | egrep -v "instance|Created" | awk '{print $1}' | awk -F "-" '{print $1}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

nhm_kpi_overview() {
  echo
  echo -e "\e[0;32mNumber of KPIs expected from NHM_01_02 profile:\e[0m"
  echo -e "\e[0;32m===============================================\e[0m"
  ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep -i number /var/log/enmutils/daemon/nhm_01_02.log" | sed "s/^/\t/g"
}

shm_history_overview() {
  echo
  echo -e "\e[0;32mSUMMARY OF LARGE SHM BACKUP & UPGRADE JOBS THIS MONTH:\e[0m"
  echo -e "\e[0;32m======================================================\e[0m"
  echo -e "\e[0;35mSHM_23 1K MLTN_INDOOR BACKUP\e[0m" | sed "s/^/\t/g"
  grep SHM_23_MLTN /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  echo
  echo -e "\e[0;35mSHM_24 1K MLTN_INDOOR UPGRADE\e[0m" | sed "s/^/\t/g"
  grep SHM_24_MLTN /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  echo
  echo -e "\e[0;35mSHM_31 500 MLTN_OUTDOOR UPGRADE\e[0m" | sed "s/^/\t/g"
  grep SHM_31_MINI /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  echo
  echo -e "\e[0;35mSHM_32 500 MLTN_OUTDOOR BACKUP\e[0m" | sed "s/^/\t/g"
  grep SHM_32_MINI /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  echo
  echo -e "\e[0;35mSHM_33 300 ROUTER6672 UPGRADE\e[0m" | sed "s/^/\t/g"
  grep SHM_33_ROUTER /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  echo
  echo -e "\e[0;35mSHM_34 1K ROUTER6672 BACKUP\e[0m" | sed "s/^/\t/g"
  grep SHM_34_ROUTER /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | grep -v RUNNING | uniq
  cli_app 'shm status --all' | grep SHM_34 | awk '{$2="";print $0}' | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mMANUAL SHM UPGRADE JOBS\e[0m" | sed "s/^/\t/g"
  for i in $(grep -i "UPGRADE.*administrator" /ericsson/enm/dumps/rv_dailychecks/rv_dailychecks_${Date2}* | grep -v "SHM_" | awk '{$1=$3="";print $0}' | sed "s/^/\t/g" | egrep -v "RUNNING|cleanup" | awk '{print $1}' | egrep -v "^Job|^$" | sort | uniq); do
    echo -e "\e[0;33m${i}\e[0m" | sed "s/^/\t/g"
    cli_app "shm status -jn $i" | sed -n '{1,20p}' | sed "s/^/\t/g"
  done
  echo -en "\n\n"
  echo -e "\e[0;35mSUMMARY OF OTHER LARGE SHM JOBS\e[0m" | sed "s/^/\t/g"
  grep "administrator" /ericsson/enm/dumps/rv_dailychecks/ -r | egrep -v "EnmApplicationError|Name :|Response:|ENIQ|administrator.cf|updated by the system" | awk '$5>10 {$1="";print $0}' | grep -v "SHM_" | sort -nk8 | uniq | sed "s/^/\t/g" | tail -8
  echo -en "\n\n"
}

vnflcm_info() {
  echo
  echo -e "\e[0;32mVNF LCM Info: \e[0m"
  echo -e "\e[0;32m=============\e[0m"

  if [ ${env_type} == "cloud" ]; then
    echo -e "\e[0;35mVNF LCM Version: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "vnflcm version" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mVNF LCM Vim List: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "vnflcm vim list" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mVNF LCM Vim Tenant List: \e[0m" | sed "s/^/\t/g"
    #vnflcm vim list-tenant --name vim_vio-5625
    vim_name=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "vnflcm vim list" | grep OPENSTACK | awk '{print $2}' | head -1)
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "vnflcm vim list-tenant --name ${vim_name}" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mDisplay list of Workflow Package/s installed: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "wfmgr bundle list" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mDisplay list of process id & definition Name of Workflows: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${vnflaf_external_ip} "wfmgr workflow processid-list" | sed "s/^/\t\t/g"
    echo

  fi
}

pm_recent_collection() {
  echo
  echo -e "\e[0;32mSUMMARY OF PM STATS COLLECTION OVER PAST TWO HOURS:\e[0m"
  echo -e "\e[0;32m===================================================\e[0m"
  if [ ${env_type} == "cloud" ]; then
    for i in $(${CLI_APP} "cmedit get * NetworkElement.neType -ns=OSS_NE_DEF" | grep neType | cut -d":" -f2 | sort -u); do
      echo -e "\e[0;35m $i Node Type\e[0m"
      #/root/rvb/bin/Rest_API_PM_check.sh $i $date_stamp $start_hour $end_hour | sed 's/^/\t\t/g';
      #echo;
      /root/rvb/bin/PM_missed.sh $i $date_stamp $start_hour $end_hour | sed 's/SubNetwork/\n\tSubNetwork/g' | sed 's/^/\t\t/g'
      echo
    done
  else
    for i in $(${CLI_APP} "cmedit get * NetworkElement.neType -ns=OSS_NE_DEF" | grep neType | cut -d":" -f2 | sort -u); do
      echo -e "\e[0;35m $i Node Type\e[0m"
      #ssh -o StrictHostKeyChecking=no -tt $WORKLOAD_VM "/root/rvb/bin/Rest_API_PM_check.sh $i $date_stamp $start_hour $end_hour" | sed 's/^/\t\t/g';
      #echo;
      #Cleanup previous files
      rm -f /tmp/fls*
      rm -f /tmp/ERAHCHU/ERAHCHU_fls_dump.txt*
      rm -f /tmp/ERAHCHU/fls_*
      rm -f /tmp/ERAHCHU/rop*
      rm -f /tmp/ERAHCHU/Missed*
      rm -f /tmp/ERAHCHU/Duplicate*
      rm -f /tmp/ERAHCHU_fls_dump.txt*
      ssh -o StrictHostKeyChecking=no -tt $WORKLOAD_VM "/root/rvb/bin/PM_missed.sh $i $date_stamp $start_hour $end_hour" | sed 's/^/\t\t/g'
      echo
    done
    #Command to check if ML Indoor continuous file exists in PMIC FS:
    #ll /ericsson/pmic[12]/XML/SubNetwork\=NETSimW\,ManagedElement\=CORE08MLTN6-0-1-07/A20191204.1315+0000-1330*continuous*
  fi
}

vms_oms_info() {
  echo
  echo -e "\e[0;32mOVERVIEW OF VMS & OMS DETAILS:\e[0m"
  echo -e "\e[0;32m==============================\e[0m"

  if [ ${env_type} == "cloud" ]; then
    echo -e "\e[0;35mVMS - SENM Audit: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "/opt/ericsson/senm/bin/audit_senm.sh -l -e /vol1/senm/etc/sed.json" | sed "s/^/\t\t/g"
    echo
    echo -en "\e[0;35mOMS VIO patch version:\t\e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "ssh -t -t viouser@oms  "\""exec sudo -i "\"" viopatch version" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mOMS VIO patch list: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "ssh -t -t viouser@oms  "\""exec sudo -i "\"" viopatch list" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mOMS VIO CLI Show: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "ssh -t -t viouser@oms  "\""exec sudo -i "\"" viocli show" | sed "s/^/\t\t/g"
    echo
    echo -e "\e[0;35mOMS VIO CLI Deployment Status: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "ssh -t -t viouser@oms  "\""exec sudo -i "\"" viocli deployment status" | sed "s/^/\t\t/g"

  fi
}

vms_sienm_hc() {
  echo
  echo -e "\e[0;32mVMS SIENM Health Check:\e[0m"
  echo -e "\e[0;32m=======================\e[0m"

  if [ ${env_type} == "cloud" ]; then
    echo -e "\e[0;35mRun SIENM Health Check on VMS: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "/usr/bin/python /opt/ericsson/senm/bin/sienm_hc.py" | sed "s/^/\t\t/g"
    #bash scripts that are run for the HC are stored in VMS here: /opt/ericsson/senm/lib/sienm_hc/check*
    echo
    echo -e "\e[0;35mLatest HC_Summary file Output: \e[0m" | sed "s/^/\t/g"
    ssh -o StrictHostKeyChecking=no ${vms_ip_vio_mgt} "ls /vol1/senm/log/html/HC_Summary* | tail -1 | xargs cat" | sed "s/^/\t\t/g"
  fi

}

consul_rtt_time() {
  if ${env_type} == "cloud" ]; then
    echo -e "\e[0;32mConsul Round Trip Times (RTT):\e[0m"
    echo -e "\e[0;32m==============================\e[0m"
    echo -e "\e[0;35mCurrent Consul RTT times from VNF-LAF to consul hosts: \e[0m" | sed "s/^/\t/g"
    #                ssh -o StrictHostKeyChecking=no -tt -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i /var/tmp/enm_keypair.pem cloud-user@${vnflaf_internal_ip}" "exec sudo -i" for h in $(consul members | tail -n +2 | awk '{print $1}'); do rtt=$(consul rtt $h | sed 's@.*rtt: \([^(]\+\).*@\1@g'); echo "$rtt : $h"; done | sort | sed "s/^/\t/g"
  fi
}

#while getopts "hw" opt; do
#    case $opt in
#        h ) displayHelpMessage; exit 0 ;;
#        w ) ;
#               exit 0;;
#        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
#    esac

#env_type
#pm_recent_collection
#exit

echo
date
echo
echo "COMMENCING RV DAILY CHECKS RUN:"
echo "==============================="
env_type
check_ddp_mountpoint
enm_baseline
litp_baseline
torutils_info
cm_node_numbers
network_breakdown
platform_type
cm_network_status
network_status_check
cm_network_cell_count
stkpi_netex_01
cm_unsynched_nodes_by_type
cm_list_unsynched_nodes
service_reg_consul_checks
vnflcm_info
vms_oms_info
vms_sienm_hc
vcs_group_status
vcs_info
vcs_cluster_node_status
mo_numbers
neo4j_table
neo4j_status
neo_leader_moves
neo4j_info
neo4j_overview_trans
neo4j_list_trans
neo4j_list_queries
dps_events_summary
netsim_rnc_bandwidth_setting
local_file_system_sizes
file_system_sizes
saved_searches
collections
stkpi_crons
cm_configs
cm_import_status
cmimport_05_stkpi
cm_activations_status
config_copy_info
cm_revocation_info
config_delete_info
cm_nhc_status
cm_export_status
eniq_integration_status
#cm_cm_nbi
stkpi_cm_change
stkpi_cm_sync_mo_count
ldap_overview
nhm_kpi_overview
cm_solr
cm_amos_sessions
amos_workload_checks
amos_command_breakdown_per_profile
amos_housekeeping
list_dumps
fm_alarm_count
fm_node_status
fm_alarm_status_db_overview
fm_hb_failure
fm_enm_alarms
fm_route_policy_status
fm_nbi
fmx_checks
pm_stats
pm_recent_collection
pmic_pib_values
kpi_overview
shm_info
#shm_history_overview
bur_info
db_vcc_checks
cmsync_setup_notifications
netconf_session
user_info
amos_temp_users
db_opendj_replication_status
sso_active_count
sso_replication_state
elasticsearch_rejected_index_count
san_healthcheck
snapshot_size
db_postgres_checks
db_vxlist_vol
#db_versant_fragmentation_report
#db_dead_trans_count
#db_dead_trans_list
versant_overview
db_versant_trans
db_optimistic_lock_trans
db_dead_lock_trans
db_long_living_trans
workload_status
#workload_errored_nodes
profiles_producing_errors

echo
date
echo

rm -rf ${rv_dailychecks_tmp_file}

#for i in {cmsync_01,cmsync_02,cmsync_03,cmsync_04,cmsync_05,cmsync_06}; do echo $i; workload list all --profiles $i | grep LTE | awk '{print $1}' | cut -c6-11|uniq -c | sort -nk2;done
# workload list all | grep -i error -B2 | egrep -i "LTE|SGSN|RNC[0-9][0-9] |[0-9]RBS[0-9]" | awk '{print $1}' | cut -c6-11|sort | uniq -c | sort -nk2

#[root@ieatenmpcb01-cmserv-1 log]# netstat -na | grep 7687 | grep -i TCP |  wc -l

#Check if SFS/VA node node had a failover
#ssh support@$(grep sfs_console_IP /software/autoDeploy/MASTER_siteEngineering.txt | awk -F "=" '{print $2}') 'grep "is in Down State" /var/log/messages*'

#SIU/TCU ROP Info
#grep OUTSIDE /ericsson/pmic1/tmp_push/stn_log/$(date +%Y%m%d)/*.csv --count

#Long running shm jobs
#BACKUP_RadioNode_Wfmyyy BACKUP  SHM_06_0415-14042158_u8 1       50.0    RUNNING         16/04/2018 15:54:46             21h 59m 23s

#/opt/ericsson/fmx/tools/bin/logviewer -s fmx -d "2018-04-18T15:00:00"
#[16:30:28 root@ieatlms4615-1:licenses ]# sshvm svc-3-fmx "/opt/ericsson/fmx/tools/bin/logviewer -s lcmserv" | grep -v CROND |sed 's/#012/\n/g'| sed 's/#011/\t/g'

#[10:31:47 root@ieatwlvm7007:~ ]# cli_app 'pkiadm extcalist'

#Imports/Exports with large node numbers:
#[16:59:13 root@ieatlms4615-1:~ ]# cli_app 'cmedit import -st -j 36408'
#Job Status
#Job ID  Status  Start date/time End date/time   Elapsed Time    Nodes copied    Nodes not copied        Managed objects created Managed objects updated Managed objects deleted Actions performed     Failure Information      File Name       Configuration
#36408   COMPLETED       2018-05-22T15:31:55     2018-05-22T15:53:55     0h 22m 0s       0       0       0       1000    0       0               434server.xml   Live
#Retrieved import job details successfully
#[16:59:41 root@ieatlms4615-1:~ ]#

#/ericsson/enm/dumps/ebsl_check_script/readme

# Profiles reaching 83 or 90 days expiry
#          AP_16: 26-Jun 08:49:05: [ProfileError] ValueError: 'Invalid login, password change required for user [AP_16_0402-15022736_u1]. Please change it via ENM login page'

# | column -t

#DDP last upload time:
#[14:34:15 root@ieatwlvm7007:~ ]# grep -i lastupload /var/log/enmutils/debug.log | grep 2018-07-31 | head -n 7 | grep 434 --color | sed 's/{/\n{/g' | grep 2018 | egrep "432|434|435|437"

#Netsim HC - root user:
#/var/simnet/HC/enm-ni-simdep/scripts/genstats_prechecks.sh
# /var/simnet/HC/enm-ni-simdep/scripts/netsimHealthCheck.sh

#Periodic Netsim Healthchecks
#cat /netsim_users/pms/logs/periodic_healthcheck.log

# Check for SFS restarts

#Consistently high logging

#Get nodes unsynched per netsim
#To help
#for i in `list_unsynced | egrep -v "NodeId|NetworkElement|instance" | cut -c 1-9 | sort | uniq | sort -nrk1`;do echo -en "$i:\t";grep -ril $i /opt/ericsson/enmutils/etc/nodes/ | grep -oP ieatnetsimv5004-[0-9]{2}; done

#Fix up netsim_rnc_bandwidth_setting so that it checks the nodes files on the WLVM for RNCs

#neo_leader_moves
#> /var/tmp/neo4j_leader
#for i in `grep neo4j /etc/hosts | awk '{print $2}'`; do sshvm $i 'egrep "Moving to LEADER state at term|Leader changed from MemberId" /ericsson/neo4j_data/logs/debug.log* | tail -10' >> /var/tmp/neo4j_leader;sed -i "s/^debug/$i: 20/g" /var/tmp/neo4j_leader;done
#cat /var/tmp/neo4j_leader|grep INFO | sort -k2 | awk '{$5=""; print $0;}'

#/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action alarms_open_count
#/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action counts
#/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action cluster_overview

#Monitor /ericsson/neo4j_data

#/ericsson/3pp/neo4j/bin/cypher-shell -a  bolt://10.247.246.44:7687 "CALL dbms.listTransactions() YIELD transactionId, elapsedTimeMillis, username, currentQuery, requestUri, clientAddress, status;" -u neo4j -p Neo4jadmin123
#/ericsson/3pp/neo4j/bin/cypher-shell -a  bolt://10.247.246.44:7687 "CALL dbms.listQueries() YIELD elapsedTimeMillis, clientAddress, status, query;" -u neo4j -p Neo4jadmin123

#Log onto leader neo4j instance:
#sshvm $(sshvm db-2 '/opt/ericsson/ERICddc/monitor/appl/TOR/qneo4j --action cluster_overview' | grep LEADER | awk -F ":" '{print $1}')

#AMOS VM
#/opt/ericsson/amos/moshell/pstool -h

#cmimport_05 alternative
#for i in `ssh -o StrictHostKeyChecking=no $WORKLOAD_VM "grep 'POST request to.*files' /var/log/enmutils/daemon/cmimport_05.log | grep $(date +%Y-%m-%d) | grep -oP jobs.*files | grep -oP "\""[0-9]{1,6}"\"" | sort | uniq"`;do ssh -o StrictHostKeyChecking=no $WORKLOAD_VM " egrep ${i} /var/log/enmutils/daemon/cmimport_05.log | egrep "\""DEBUG   Job ${i}|HISTORY CHANGES.*operations"\"" | egrep -v 'EXCEPTION'";echo "*******";done

#New ldap replication check on db-1
#/opt/opendj/bin/dsreplication status --hostname localhost --adminUID repadmin -w ldapadmin --trustAll -p 4444

#STKPI SHM
#[10:17:32 root@ieatlms5218:~ ]# egrep "date +%a"\"" "\""%b"\"" "\""%d|SHM INVENTORY SYNC" /ericsson/enm/dumps/stkpi_shm_inv_sync_random_nodes_kpi.log

#cm sync_01 KPI results
#zgrep "ieatnetsimv5004-12_LTE39ERBS00077" *.csv.gz | egrep "SYNC_NODE.ATTRIBUTE_DPS_HANDLER_COMPLETE_SYNC, DETAILED" | sed -r 's/(.*)@JBOSS.*(NetworkElement.*ERBS[0-9]{5}).*(took.*execute).*$/\1 \2 \3/'

#STKPI SHM
#[10:17:32 root@Info on most recent Bacieatlms5218:~ ]# egrep "date +%a"\"" "\""%b"\"" "\""%d|SHM INVENTORY SYNC" /ericsson/enm/dumps/stkpi_shm_inv_sync_random_nodes_kpi.log
#grep "SHM INVENTORY SYNC" /ericsson/enm/dumps/stkpi_shm_inv_sync_random_nodes_kpi.log -A4

#cm sync_01 KPI results
#zgrep "ieatnetsimv5004-12_LTE39ERBS00077" *.csv.gz | egrep "SYNC_NODE.ATTRIBUTE_DPS_HANDLER_COMPLETE_SYNC, DETAILED" | sed -r 's/(.*)@JBOSS.*(NetworkElement.*ERBS[0-9]{5}).*(took.*execute).*$/\1 \2 \3/'

#/var/log/enmutils/redis/redis_monitoring.log
#mem_fragmentation_ratio’
#Taking the Endurance server as an example, the log file /var/log/enmutils/redis/redis_monitoring.log shows an ‘average mem_fragmentation_ratio’ of 0.89. For optimal performance, the fragmentation ratio should be slightly greater than 1. A value of less than this indicates memory swapping. Ie: the Linux os is moving redis data (workload profile data)  from memory to disk.  Writing or reading from disk is up to 5 times slower than writing or reading from memory.

#DPS Events Script
#ssh ieatlms4421
#/ericsson/enm/dumps/.scripts/.dps_events_flow_invocation_Internal.sh LMI_ENM404 01 19

#Check for inconsistencies between Product Version & OssModelIdentity / nodeModelIdentity versions:
#for i in `cli_app 'cmedit get LTE* networkelement -ne=RadioNode'| awk -F "=" '{print $2}' | cut -c1-8 | sort | uniq`; do echo $i;cli_app "cmedit get $i* networkelement.(nodeModelIdentity,neProductVersion,ossModelIdentity)  -t" | egrep LTE | awk '$1="";{print}' | sort | uniq -c | sort -nrk1 | sed 's/^/\t/g';done
# Last successful full sync:
# cli_app 'cmedit get LTE02dg2ERBS00070;LTE02dg2ERBS00074;LTE08dg2ERBS00033 NetworkElement.(lastSuccessfulSoftwareSync,neProductVersion)'

#What is ddp are mounted:
#mount | grep ddp

#Check neo4j instances are in sync
#for i in {10.247.246.10,10.247.246.44,10.247.246.250};do /ericsson/3pp/neo4j/bin/cypher-shell -u neo4j -p Neo4jadmin123 -a $i:7687 'call dbms.queryJmx("org.neo4j:instance=kernel#0,name=Transactions") yield attributes' | grep -v "\- \- \- " | sed 's/},/\n/g' | grep -oP ": \".*";done
# /ericsson/3pp/neo4j/bin/cypher-shell -u neo4j -p Neo4jadmin123 -a 10.10.0.146:7687 'call dbms.queryJmx("org.neo4j:instance=kernel#0,name=Transactions") yield attributes'
#https://confluence-nam.lmera.ericsson.se/display/EZH/NEO4J+Troubleshooting+Guide+on+ENM+on+Cloud

#COM-ECIM Flow Control Parameter
#[05:36:02 root@ieatlms5218:~ ]# /ericsson/pib-scripts/etc/config.py read --app_server_address=svc-3-mscmce:8080 --name=com_ecim_policy_flow_control_config
#["FLOW_CONTROL_PERIOD:20","//MEDIATION/SyncSgsnNodeFlow/1.0.0:2","//MEDIATION/SyncSgsnNodeFlow/2.0.0:2","//MEDIATION/SyncRadioNodeFlow/1.0.0:10","//MEDIATION/SyncRadioNodeFlow/2.0.0:10","//COM_ECIM_MED/SyncComLargeNodeFlow/1.0.0:1","//IPOSOI_MED/IposOiSyncNodeFlow/1.0.0:1"]

#PM collection for the day
#zgrep "PMIC_FILE_COLLECTION_STATISTICS" *csv.gz | grep "ropPeriodInMinutes=15" | less

#this causes core dumps
#[11:19:40 root@ieatwlvm7040:enmlogs ]# zcat 19_partial.csv.gz | grep -o -P '(?<=ropPeriodInMinutes=15,).*(?=,numberOfBytesStored)'
#numberOfFilesCollected=1975,numberOfFilesFailed=0
#numberOfFilesCollected=2094,numberOfFilesFailed=0
#numberOfFilesCollected=2082,numberOfFilesFailed=0
#numberOfFilesCollected=1987,numberOfFilesFailed=0
#Aborted (core dumped)
#zgrep "PMIC_FILE_COLLECTION_STATISTICS" 19_partial.csv.gz 2[012]_partial.csv.gz | grep -oP '(?<=^).*ropPeriodInMinutes=15.*(?=,numberOfBytesStored)'

#Apache Service Unavailable requests

#NEO CC
#[15:52:43 root@ieatlms5685:~ ]# sshvm db-2 "egrep 'Neo4j BUR/CC Orchestrator|Neo4jBackupAndCC' /var/log/messages | egrep 'Initialising for taking backup|Neo4j Backup/Consistency Check|Neo4j BUR/CC Orchestrator' | egrep "\""$(date +%b" "%d)|$(date | awk '{print $2,"",$3}')"\"""
#Jul  1 00:07:08 ieatrcxb5595 Neo4j BUR/CC Orchestrator: DEBUG: Running command locally: /opt/VRTSvcs/bin/hagrp -list
#Jul  1 00:07:08 ieatrcxb5595 Neo4j BUR/CC Orchestrator: DEBUG: Running command locally: /opt/VRTSvcs/bin/hagrp -display Grp_CS_db_cluster_sg_neo4j_clustered_service
#Jul  1 00:07:08 ieatrcxb5595 Neo4j BUR/CC Orchestrator: INFO: BurCopyFlow skipped
#Jul  1 14:12:11 ieatrcxb5595 Neo4jBackupAndCC: INFO: Initialising for taking backup, please wait...

#Fragmentation Checks (db nodes)
#[root@ieatrcxb5649 ~]# /opt/VRTS/bin/fsadm -E /ericsson/neo4j_data/

#/ericsson/pib-scripts/etc/config.py read --app_server_address=svc-4-pmserv:8080 --name=stopAllOperationOnFlsDB

#Simplify vcs check for an online service check of neo or any other SG
#/opt/ericsson/enminst/bin/vcs.bsh --groups -g Grp_CS_db_cluster_sg_neo4j_clustered_service -a ONLINE -c db_cluster

#lvsrouter messages
#egrep "Entering BACKUP STATE|Transition to MASTER STATE|Received higher prio advert" /var/log/messages
#egrep "Entering BACKUP STATE|Transition to MASTER STATE|Received higher prio advert" /var/log/messages

#neo4j cc:
#[root@vio-5625-vnflaf-services-0 log]# egrep -i "Neo4j Consistency Check has been set to start|Neo4j consistency check.*Results" server.log
#2019-09-10 10:08:34,321 INFO  [com.ericsson.oss.services.wfs.task.api.WorkflowLogger] (job-executor-tp-threads - 677) Neo4j Consistency Check has been set to start
#2019-09-10 11:39:06,436 INFO  [com.ericsson.oss.services.wfs.task.api.WorkflowLogger] (job-executor-tp-threads - 1038) Neo4j consistency check successful. Results: 2019-09-10 10:20:39.544+0100 INFO [o.n.k.i.s.f.RecordFormatSelector] Selected RecordFormat:StandardV3_4[v0.A.9] record format from store /ericsson/neo4j_data/databases/graph.db

#List VIO Backups on VMS
#[11:14:45 root@vms:~ ]# /opt/ericsson/bur-config-ombs/bin/senmrestore --list-backup
#                             Select Backup to Restore
#Select  Deployment ID  Backup Tag            ENM Version      Date
#---------------------------------------------------------------------------------
#1       vio-5625       SENM_20190908_000102  19.12::1.79.119  2019-09-08 00:01:04
#2       vio-5625       SENM_20190901_000103  19.12::1.79.119  2019-08-31 23:58:30
#3       vio-5625       SENM_20190825_000102  19.11::1.78.135  2019-08-24 23:57:52
#4       vio-5625       SENM_20190818_000102  19.11::1.78.134  2019-08-17 23:54:13
#[11:14:59 root@vms:~ ]#

#Backup cron on VMS: Ansible: backup_rule
#1 0 * * 0 /opt/ericsson/bur-config-ombs/bin/senmbackup

#fm_node_status
#[root@vio-5625-secserv-0 ~]# strings /ericsson/tor/data/fm/fmrouterpolicy/data/FmRouterPolicyMappings.txt | grep -oP 'vio-5625-mssnmpfm-[0-9]{0,2}' | sort | uniq -c | sort -nrk1
#   2625 vio-5625-mssnmpfm-0
#   2375 vio-5625-mssnmpfm-1
#[root@vio-5625-secserv-0 ~]#

#Rajesh PM scripts
#/root/rvb/bin/Quick_PM_data_Check.sh
#/root/rvb/bin/PM_missed.sh
#/root/rvb/bin/Rest_API_PM_check.sh

#SIENM VMS Log directory
#/vol1/senm/log

#consul RTT times:
# for h in $(consul members | tail -n +2 | awk '{print $1}'); do consul rtt $h | awk '{print $6 " : " $2}';done | sort
# for h in $(consul members | tail -n +2 | awk '{print $1}'); do rtt=$(consul rtt $h | sed 's@.*rtt: \([^(]\+\).*@\1@g'); echo "$rtt : $h"; done | sort

#Include EBS exports alongside ENIQ export job status
#EBS_TOPOLOGY_DAILY_EXPORT_RadioNode & EBS_TOPOLOGY_DAILY_EXPORT_ERBS

#update pmic_pib_values - check this.
#/ericsson/pib-scripts/etc/config.py read --all --app_server_address svc-4-pmserv:8080 | sed s/,/\\n/g |grep "GLOBAL___" | egrep -i "pmic.*retention|fileRecoveryHoursInfo" | awk -F "___" '{print $2}' | awk -F "\"" '{print $1}'

#Check is there are old PM files in the smrs push locations:
#/home/smrs/MINI-LINK/pm_push_2/tn_pm_data
#/home/smrs/MINI-LINK/pm_push_1/tn_pm_data
#/home/smrs/smrsroot/pm_push_1/mini-link-6352
#/home/smrs/smrsroot/pm_push_2/mini-link-6352
#/home/smrs/smrsroot/pm_push_1/esc
#/home/smrs/smrsroot/pm_push_2/esc
#/home/smrs/smrsroot/pm/sbg-is

#Another way to look at the file system sizes:
#for i in `more /proc/mounts |egrep 'vx|dev'|awk '{print $2}'`;do echo -e "\n######$i######";df -hP $i;sleep 2;done


