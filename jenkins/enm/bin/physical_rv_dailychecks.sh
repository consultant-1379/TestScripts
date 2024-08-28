#!/bin/bash

CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
CLUSTER=$(grep -ri san_siteId /software/autoDeploy/*site* | head -1 | awk -F '=ENM' '{print $2}')
consul_members='/var/tmp/consul_members.txt'
DATE=$(date +%Y%m%d)
DDP_DATE=$(date +%d%m%y)
dt1=$(date "+%Y%m%d")
mscm_1_ip_internal=$(grep mscm_1_ip_internal /software/autoDeploy/MASTER_siteEngineering.txt | awk -F "=" '{print $2}')
mscm='svc-1-mscm'
NETSIM=$(grep netsim /root/rvb/deployment_conf/5${CLUSTER}.conf | head -1 | awk -F "\"" '{print $2}' | awk -F "-" '{print $1}')
NETWORK="/opt/ericsson/enmutils/bin/network"
rv_dailychecks_tmp_file="/ericsson/enm/dumps/physical_rv_dailychecks_tmp_file.log"
sshvm="/root/rvb/bin/ssh_to_vm_and_su_root.exp"
UNSYNCHED='/opt/ericsson/enmutils/bin/cli_app "cmedit get * CmFunction.syncStatus!="SYNCHRONIZED" -t"'
user_mgr="/opt/ericsson/enmutils/bin/user_mgr"
VCC_DATE1=$(date +%b" "%d)
VCC_DATE2=$(date | awk '{print $2,"",$3}')
VCS="/opt/ericsson/enminst/bin/vcs.bsh"
WORKLOAD=/opt/ericsson/enmutils/bin/workload
workload_vm=$(grep wlvm /root/.bashrc | awk -F "=" '{print $2}' | grep -oP "ieat.*se")

#Determine if env is cloud or physical
env_type() {
  #Determine if env is cloud or physical based on existence of /var/ericsson/ddc_data/config/ddp.txt on LMS (physical). Otherwise this is considered a cloud env.
  echo
  echo -e "\e[0;32mChecking environment type:\e[0m"
  echo -e "\e[0;32m==========================\e[0m"
  env_type=$(if [ -e /var/ericsson/ddc_data/config/ddp.txt ]; then echo "physical"; else echo "cloud"; fi)
  echo "This is a ${env_type} env" | sed "s/^/\t/g"

  if [ ${env_type} == "cloud" ]; then
    keypair="/var/tmp/enm_keypair.pem"
    consul_members='/var/tmp/consul_members.txt'

    ssh -t -t -i /var/tmp/enm_keypair.pem cloud-user@$EMP "exec sudo -i" consul members list >${consul_members}
    #Copy pem file to EMP VM:
    scp -i /var/tmp/enm_keypair.pem /var/tmp/enm_keypair.pem cloud-user@$EMP:/var/tmp &>/dev/null

    #Cloud Specific Parameters to be setup:
    vnflaf_internal_ip=$(grep vnflaf-services ${consul_members} | awk '{print $2}' | awk -F ":" '{print $1}')
    vnflaf_external_ip=$(ssh -i /var/tmp/enm_keypair.pem cloud-user@$EMP "ssh -t -t -i /var/tmp/enm_keypair.pem cloud-user@${vnflaf_internal_ip}" "exec sudo -i" ifconfig eth1 | grep -w inet | awk '{print $2}')
    esmon_ip=$(grep esmon ${consul_members} | awk '{print $2}' | awk -F ":" '{print $1}')
    ddp_server=$(ssh -i /var/tmp/enm_keypair.pem cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -i /var/tmp/enm_keypair.pem cloud-user@${esmon_ip}" "exec sudo -i" grep ddcDataUpload /var/log/cron | tail -1 | grep -oP ddpenm"\d")
    #rv_env=`ssh -i /var/tmp/enm_keypair.pem cloud-user@$EMP "ssh -t -t -i /var/tmp/enm_keypair.pem cloud-user@${esmon_ip}" "exec sudo -i" cat /var/ericsson/ddc_data/config/ddp.txt | sed s/^....//`
    CLUSTER=$(ssh -o StrictHostKeyChecking=no -i ${keypair} cloud-user@$EMP "ssh -o StrictHostKeyChecking=no -tt -o StrictHostKeyChecking=no -i ${keypair} cloud-user@${esmon_ip}" "exec sudo -i" grep ddcDataUpload /var/log/cron | tail -1 | grep -oP "\-s.*" | awk '{print $2}' | grep -oP ".*[0-9]{3}")

  else
    ddp_server=$(grep ddcDataUpload /var/log/cron | tail -1 | grep -oP ddpenm"\d")
    #rv_env=`cat /var/ericsson/ddc_data/config/ddp.txt | sed s/^....//`
    CLUSTER=$(grep ddcDataUpload /var/log/cron | tail -1 | grep -oP "\-s.*" | awk '{print $2}' | grep -oP ".*[0-9]{3}")
  fi
}

[ ! -d /ericsson/enm/dumps/physical_rv_dailychecks/ ] && mkdir -p /ericsson/enm/dumps/physical_rv_dailychecks/ && chmod 777 /ericsson/enm/dumps/physical_rv_dailychecks/

if [ $# -gt 0 ]; then
  echo -e "\e[0;32m  Script Help - Run script as follows with no parameters   \e[0m"
  echo "  	./rv_dailychecks.bsh"
  echo
  echo -e "\e[0;35mPRE-REQUISITES: \e[0m" | sed "s/^/\t/g"
  echo "1). Ensure .pem key file is on WORKLOAD VM." | sed "s/^/\t/g"
  echo "2). Ensure .pem key file is on EMP VM as /var/tmp/enm_keypair.pem with grp & owner set as cloud-user" | sed "s/^/\t/g"
  echo "3). Ensure VNF_LAF & EMP variables are set in .bashrc on workload vm" | sed "s/^/\t/g"
  echo "4). Ensure passwordless connection from EMP to workload VM"
  echo "5). Ensure workload_vm variable is set in /root/.bashrc file"
  exit 1
fi

touch ${rv_dailychecks_tmp_file}

read_rv_dailychecks_tmp() {
  sleep 15
  if [ -s "${rv_dailychecks_tmp_file}" ]; then
    cat ${rv_dailychecks_tmp_file} | sed "s/^/\t\t/g"
    truncate -s 0 ${rv_dailychecks_tmp_file}
  else
    echo "No entries" | sed "s/^/\t\t/g"
  fi
}

sfs_not_ready() {
  echo
  echo -e "\e[0;32mOccurrences of \"SFS not ready\" messages:\e[0m"
  echo -e "\e[0;32m========================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "SFS not ready" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"SFS not ready\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "SFS not ready" | sed "s/^/\t/g"
  echo -e "\e[0;35mTotal count of \"SFS not ready\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo -e "\e[0;35mFirst & Last occurrences of \"SFS not ready\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | head | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | tail | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

versant_connection_pool() {
  echo
  echo -e "\e[0;32mOccurrences of \"connection pool full\" messages:\e[0m"
  echo -e "\e[0;32m===============================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "connection pool full" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"connection pool full\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "connection pool full" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"connection pool full\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"connection pool full\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

queues_hanging() {
  echo
  echo -e "\e[0;32mQueues with occurrences of\e[0m \e[0;35m\"There are possibly consumers hanging on a network operation:\"\e[0m"
  echo -e "\e[0;32m========================================================================================\e[0m"
  zgrep "There are possibly consumers hanging on a network operation" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep -oP "Queue.*" | awk '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  #        zgrep "There are possibly consumers hanging on a network operation" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep -oP "Queue.*" > /dev/null
  #        if [ $? == 1 ]; then echo "No Queues reported \"There are possibly consumers hanging on a network operation\""; fi | sed "s/^/\t/g"
}

full_queues() {
  echo
  echo -e "\e[0;32mFull Queues:\e[0m"
  echo -e "\e[0;32m============\e[0m"
  zgrep "Address \"jms\.queue.* is full" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed 's/#012/\n/g' | grep -oP "Address \"jms\.queue.* is full" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  #        zgrep "Address \"jms\.queue.* is full" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz > /dev/null
  #        if [ $? == 1 ]; then echo "No reports of full queues"; fi | sed "s/^/\t/g"
}

full_topics() {
  echo
  echo -e "\e[0;32mFull Topics:\e[0m"
  echo -e "\e[0;32m============\e[0m"
  zgrep "Address \"jms\.topic.* is full" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep -oP "Address \"jms\.topic.* is full" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  #        zgrep "Address \"jms\.topic.* is full" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz > /dev/null
  #        if [ $? == 1 ]; then echo "No reports of full topics"; fi | sed "s/^/\t/g"
}

maximum_delivery_attempts() {
  echo
  echo -e "\e[0;32mQueues with occurrences of\e[0m \e[0;35m\"maximum delivery attempts reached, sending it to Dead Letter Address:\"\e[0m"
  echo -e "\e[0;32m==================================================================================================\e[0m"
  zgrep "has reached maximum delivery attempts, sending it to Dead Letter Address" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | awk '{print $NF}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  #        zgrep "has reached maximum delivery attempts, sending it to Dead Letter Address" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz > /dev/null
  #        if [ $? == 1 ]; then echo "No reports of maximum delivery attempts reached"; fi | sed "s/^/\t/g"
}

rollback_transactions() {
  echo
  echo -e "\e[0;32mNumber of EJBTransactionRolledbackException received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m===============================================================\e[0m"
  echo -e "\e[0;35mList of DDP csv.gz files currently available for $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  ls -ltr /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of EJBTransactionRolledbackException received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep -c EJBTransactionRolledbackException /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of EJBTransactionRolledbackException received per VM on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep EJBTransactionRolledbackException /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep -oP "@.*@JBOSS@.*ERROR" | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

Transaction_reaper() {
  echo
  echo -e "\e[0;32mNumber of \"TransactionReaper....Marked transaction branch for rollback\" received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=========================================================================================\e[0m"
  zgrep -c "TransactionReaper.*Marked transaction branch for rollback because TMFAIL was" /net/ddpenm2/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of \"TransactionReaper....Marked transaction branch for rollback\" received per VM on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep "TransactionReaper.*Marked transaction branch for rollback because TMFAIL was" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep -oP "[a-z]{3,9}@JBOSS@" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

jprobe_cluster_membership_query() {
  echo
  echo -e "\e[0;32mJProbe Cluster Membership Queries: \e[0m"
  echo -e "\e[0;32m==================================\e[0m"
  echo -e "\e[0;35mCount of Cluster members: \e[0m" | sed "s/^/\t/g"
  ${sshvm} ${mscm} "sudo java -cp /opt/ericsson/jboss/modules/com/ericsson/oss/itpf/sdk/infinispan/7.1.1.Final/jgroups-3.6.1.Final.jar org.jgroups.tests.Probe -port 7500 -weed_out_duplicates -bind_addr ${mscm_1_ip_internal}" | grep -c cluster | sed "s/^/\t/g"
  echo -e "\e[0;35mBreakdown of Cluster members instances: \e[0m" | sed "s/^/\t/g"
  ${sshvm} ${mscm} "sudo java -cp /opt/ericsson/jboss/modules/com/ericsson/oss/itpf/sdk/infinispan/7.1.1.Final/jgroups-3.6.1.Final.jar org.jgroups.tests.Probe -port 7500 -weed_out_duplicates -bind_addr ${mscm_1_ip_internal}" | grep cluster | sort -nrk1 | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

workload_show_alarms() {
  echo
  echo -e "\e[0;32mAlarm & Notification burst info: \e[0m"
  echo -e "\e[0;32m================================\e[0m"
  ssh -o StrictHostKeyChecking=no ${workload_vm} "${WORKLOAD} show-alarms" | sed "s/^/\t/g"
}

#netsim_stopped_errored_nodes(){
#        echo
#        echo -e "\e[0;32mList of Netsim Stopped Nodes: \e[0m"
#        echo -e "\e[0;32m=============================\e[0m"
#	for i in {01..90};do echo -n "$NETSIM-$i"; ssh -X netsim@$NETSIM-$i 'echo ".show nodes stopped" | /netsim/inst/netsim_shell;echo ".show nodes error" | /netsim/inst/netsim_shell;';done| sed "s/^/\t/g"
#for i in {01..50};do echo -n "ieatnetsimv7017-$i"; ssh -X netsim@ieatnetsimv7017-$i 'echo ".show nodes stopped" | /netsim/inst/netsim_shell;echo ".show nodes error" | /netsim/inst/netsim_shell';done
#}

list_profiles() {
  echo
  echo -e "\e[0;32mFull list of all profiles: \e[0m"
  echo -e "\e[0;32m==========================\e[0m"
  ssh -o StrictHostKeyChecking=no ${workload_vm} 'workload diff | egrep -v "^$|You|Workload"' | sed "s/^/\t/g"
}

not_running_supported_profiles() {
  echo
  echo -e "\e[0;32mCheck for non-intrusive profiles that are not running but that are supported:\e[0m"
  echo -e "\e[0;32m=============================================================================\e[0m"
  ssh -o StrictHostKeyChecking=no ${workload_vm} 'workload diff --no-ansi | awk '\''$2=="NO"'\'' | awk '\''$4!="NO"'\'' | awk '\''$4!="INTRUSIVE"'\'' | awk '\''{print $1}'\''' | sed "s/^/\t/g"
}

profiles_to_be_updated() {
  echo
  echo -e "\e[0;32mList of profiles yet to be restarted on latest torutils version:\e[0m"
  echo -e "\e[0;32m================================================================\e[0m"
  if [ ${env_type} = cloud ]; then
    /opt/ericsson/enmutils/bin/workload diff --updated | sed "s/^/\t/g"
  else
    ssh -o StrictHostKeyChecking=no ${workload_vm} 'workload diff --updated' | sed "s/^/\t/g"
  fi
}

profiles_with_no_timestamp_from_today() {
  echo
  echo -e "\e[0;32mList of profiles with no entries for today in their daemon logfile:\e[0m"
  echo -e "\e[0;32m====================================================================\e[0m"
  ssh -o StrictHostKeyChecking=no ${workload_vm} "for i in $(workload status | egrep "STARTING|RUNNING|SLEEPING|DEAD" | awk '{print $1}')
            do for j in $(ls /var/log/enmutils/daemon/ | grep -iw "${i}.log" | grep -v ".gz")
                do
                    if [ $(tail -1 /var/log/enmutils/daemon/${j} | awk '{print $1}') = $(date +%Y-%m-%d) ]
                        then echo "yes"
                    else echo -e "${i}"
                    fi | xargs | grep -v yes
                done
            done" | sed "s/^/\t/g"
}

snapshot_overview() {
  echo
  echo -e "\e[0;32mDetailed Info on any existing snapshots:\e[0m"
  echo -e "\e[0;32m========================================\e[0m"
  /opt/ericsson/enminst/bin/enm_snapshots.bsh --action list_snapshot --detailed | egrep "Creation|NAS SNAP: Filesystem|NAS SNAP:  Changed|LVM SNAP: LMS snapshot:   Usage|LVM SNAP: LMS snapshot: Snapshot|SAN SNAP :  State|SAN SNAP : LUN" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mSnap Creation Times:\e[0m" | sed "s/^/\t/g"
  echo -en "From:\t\t" | sed "s/^/\t/g"
  grep "Creation" ${rv_dailychecks_tmp_file} | head -1 | grep -oP "Creation.*"
  echo -en "To:\t\t" | sed "s/^/\t/g"
  grep "Creation" ${rv_dailychecks_tmp_file} | tail -1 | grep -oP "Creation.*"
  echo
  echo -e "\e[0;35mNAS Snaps Info:\e[0m" | sed "s/^/\t/g"
  grep -oP "Filesystem.*|Changed.*" ${rv_dailychecks_tmp_file} | paste - - | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mLMS LVM Snaps Info:\e[0m" | sed "s/^/\t/g"
  grep -oP "LVM SNAP: LMS snapshot:   Usage.*|LVM SNAP: LMS snapshot: Snapshot.*" ${rv_dailychecks_tmp_file} | paste - - | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mSAN Snaps Info:\e[0m" | sed "s/^/\t/g"
  grep -oP "LUN.*|State.*" ${rv_dailychecks_tmp_file} | paste - - | sed "s/^/\t/g"

  echo
  echo -e "\e[0;35mFor full details run:\e[0m \e[0;33m/opt/ericsson/enminst/bin/enm_snapshots.bsh --action list_snapshot --detailed\e[0m" | sed "s/^/\t/g"

  >${rv_dailychecks_tmp_file}
}

unprocessed_alarms_sent_northbound() {
  echo
  echo -e "\e[0;32mNumber of Alarms sent northbound when APS has failed to store them in DB on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m===================================================================================\e[0m"
  zgrep -c "@.*-fmalarmprocessing.*@JBOSS@.*Max retries to process an alarm reached and unprocessed alarm is sent NorthBound" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"Max retries to process an alarm reached and unprocessed alarm is sent NorthBound\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep "@.*fmalarmprocessing.*@JBOSS@.*Max retries to process an alarm reached and unprocessed alarm is sent NorthBound" *.csv.gz | grep $(date +%Y-%m-%d) | head -1 | awk '{print $1}' | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  zgrep "@.*fmalarmprocessing.*@JBOSS@.*Max retries to process an alarm reached and unprocessed alarm is sent NorthBound" *.csv.gz | grep $(date +%Y-%m-%d) | tail -1 | awk '{print $1}' | sed "s/^/\t\t/g"

}

unprocessed_alarms_waiting_long_time() {
  echo
  echo -e "\e[0;32mNumber of unprocessed alarms as waiting in the buffer for long time with problematic threads on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=======================================================================================================\e[0m"
  zgrep -c "@.*fmalarmprocessing.*@JBOSS@.*unprocessed alarms as waiting in the buffer for long time with problematic threads" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"unprocessed alarms as waiting in the buffer for long time with problematic threads\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep "@.*fmalarmprocessing.*@JBOSS@.*unprocessed alarms as waiting in the buffer for long time with problematic threads" *.csv.gz | grep $(date +%Y-%m-%d) | head -1 | awk '{print $1}' | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  zgrep "@.*fmalarmprocessing.*@JBOSS@.*unprocessed alarms as waiting in the buffer for long time with problematic threads" *.csv.gz | grep $(date +%Y-%m-%d) | tail -1 | awk '{print $1}' | sed "s/^/\t\t/g"
}

notification_buffer_corrupted() {
  echo
  echo -e "\e[0;32mNumber of\e[0m \e[0;35m\"Notification Buffer Corrupted\"\e[0m\e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m================================================================\e[0m"
  zgrep -c "@.*mscmce@JBOSS.*Notification Buffer Corrupted" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo "Note: A high number of these Notification Buffer Corrupted errors will mean a high number of COM/ECIM delta syncs at the same time." | sed "s/^/\t/g"
}

sps_AMOS_EntityNotFoundException_errors() {
  echo
  echo -e "\e[0;32mNumber of\e[0m \e[0;35m\"EntityNotFoundException\"\e[0m\e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m================================================================\e[0m"
  zgrep -c "@.*-sps@JBOSS@ERROR.*EntityNotFoundException.*AMOS" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo "Note: If errors seen, check cron for setupEEForAMOSUsers & check cmscript user is able to login ok." | sed "s/^/\t/g"
}

netconfSession_errors() {
  echo
  echo -e "\e[0;32mNumber of \e[0m \e[0;35m\"Fatal error on NetconfSession.*netconf's session will be closed\"\e[0m \e[0;32m errors received on SPS instances from AMOS users on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=========================================================================================================================================\e[0m"
  zgrep -c "Fatal error on NetconfSession.*netconf's session will be closed" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
}

solr_timeout() {
  echo
  echo -e "\e[0;32mNumber of \e[0m \e[0;35m\"Timeout occurred while waiting response from server at: http://solr:8983/solr\"\e[0m \e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m======================================================================================================================\e[0m"
  zgrep -c "Timeout occurred while waiting response from server at: http://solr:8983/solr" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo "Note: If errors seen, check dlms FS size and/or if collection1 index size >200Gb on ddp. If so apply workaround in TORF-274375." | sed "s/^/\t/g"
}

no_invocation_response() {
  echo
  echo -e "\e[0;32mNumber of \e[0m \e[0;35m\"Transformer Exceptionjava.util.concurrent.TimeoutException: No invocation response received in 3000 milliseconds\"\e[0m \e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m=========================================================================================================================================================\e[0m"
  zgrep -c "No invocation response received in 3000 milliseconds" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mNumber of No invocation response received in 3000 milliseconds received per VM on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep "No invocation response received in 3000 milliseconds" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep -oP "@.*@JBOSS@ERROR" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

ocfstatus_request_timeouts() {
  echo
  echo -e "\e[0;32mNumber of \e[0m \e[0;35m\"ocfstatus - WARNING - Killing Healthcheck: REQUEST TIMEOUT exceeded\"\e[0m \e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m============================================================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep ocfstatus | grep "REQUEST TIMEOUT" | grep -oP @s.*@ | sort | uniq -c | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of occurrences: \e[0m" | sed "s/^/\t/g"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep ocfstatus | grep "REQUEST TIMEOUT" | sed "s/^/\t/g"
}

no_active_software_version_present() {
  echo
  echo -e "\e[0;32mNodes Reporting \e[0m \e[0;35m\"There is no active software version present\"\e[0m \e[0;32m errors received on $(date +%b" "%d): \e[0m"
  echo -e "\e[0;32m==========================================================================================\e[0m"
  zgrep -i "is no active software" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*.csv.gz | grep -oP NetworkElement=.*,CmFunction | sort | uniq | sed "s/^/\t/g"
  echo ""
}

versant_overview() {
  echo
  echo -e "\e[0;32mVersant Transactions:\e[0m"
  echo -e "\e[0;32m===========================\e[0m"
  echo -e "\e[0;35mFull list of Versant Processes and Threads out to clients: \e[0m" | sed "s/^/\t/g"
  ${sshvm} db1-service "su - versant -c "\""/ericsson/versant/dbscripts/health_check/versant_admin.py -r"\"" > ${rv_dailychecks_tmp_file}" &>/dev/null
  read_rv_dailychecks_tmp
}

redis_bigkeys() {
  echo
  echo -e "\e[0;32mBiggest Keys in Redis (Workload VM): \e[0m"
  echo -e "\e[0;32m====================================\e[0m"
  ssh -o StrictHostKeyChecking=no ${workload_vm} "/opt/ericsson/enmutils/.env/lib/python2.7/site-packages/enmutils/external_sources/db/redis-cli -p 6379 --bigkeys | egrep Biggest" | sed "s/^/\t/g"
}

netsim_stopped_nodes() {
  echo
  echo -e "\e[0;32mChecking for any stopped nodes on netsim: \e[0m"
  echo -e "\e[0;32m=========================================\e[0m"
  if [ ${env_type} = cloud ]; then
    for i in $(ls -ltr /opt/ericsson/enmutils/etc/nodes/ | grep -oP "ieatnetsimv[0-9]{3,4}-[0-9]{2,3}" | sort | uniq); do
      SIMS_NOT_STARTED=$(ssh -o StrictHostKeyChecking=no netsim@${i} "echo '.show allsimnes' | /netsim/inst/netsim_shell | grep 'not started' | cut -d' ' -f1")

      if [[ ${SIMS_NOT_STARTED} == "" ]]; then
        echo -e "${i}: \t INFO: All nodes are successfully started." | sed 's/^/\t\t/g'
      else
        echo -e "${i}: \t ERROR: The below list of nodes are not started. Please check" | sed 's/^/\t\t/g'
        echo ${SIMS_NOT_STARTED} | sed 's/^/\t\t\t\t\t/g'
      fi

    done
  else
    for i in $(ssh -o StrictHostKeyChecking=no ${workload_vm} "ls -ltr /opt/ericsson/enmutils/etc/nodes/|grep -oP "\""ieatnetsimv[0-9]{3,4}-[0-9]{2,3}"\"" | sort | uniq"); do
      SIMS_NOT_STARTED=$(ssh -o StrictHostKeyChecking=no netsim@${i} "echo '.show allsimnes' | /netsim/inst/netsim_shell | grep 'not started' | cut -d' ' -f1")

      if [[ ${SIMS_NOT_STARTED} == "" ]]; then
        echo -e "${i}: \t INFO: All nodes are successfully started." | sed 's/^/\t\t/g'
      else
        echo -e "${i}: \t ERROR: The below list of nodes are not started. Please check" | sed 's/^/\t\t/g'
        echo ${SIMS_NOT_STARTED} | sed 's/^/\t\t\t\t\t/g'
      fi

    done
  fi
}

netsim_erlang_crashes() {
  echo
  echo -e "\e[0;32mChecking for any Erlang Crashes on netsim: \e[0m"
  echo -e "\e[0;32m==========================================\e[0m"
  if [ ${env_type} = cloud ]; then
    for i in $(ls -ltr /opt/ericsson/enmutils/etc/nodes/ | grep -oP "ieatnetsimv[0-9]{3,4}-[0-9]{2,3}" | sort | uniq); do
      ERLANG_CRASHES=$(ssh -o StrictHostKeyChecking=no netsim@${i} "/bin/ls -ltr /netsim/inst/ | grep erl_crash* ")

      if [[ ${ERLANG_CRASHES} == "" ]]; then
        echo -e "$i: \t INFO: No Erlang Crashes." | sed 's/^/\t\t/g'
      else
        echo -e "$i: \t ERROR: The below Erlang Crashes have occurred. Please check" | sed 's/^/\t\t/g'
        echo ${ERLANG_CRASHES} | sed 's/dump/dump\n/g' | sed 's/^/\t\t\t\t\t\t/g'
      fi
    done
  else
    for i in $(ssh -o StrictHostKeyChecking=no ${workload_vm} "ls -ltr /opt/ericsson/enmutils/etc/nodes/|grep -oP "\""ieatnetsimv[0-9]{3,4}-[0-9]{2,3}"\"" | sort | uniq"); do
      ERLANG_CRASHES=$(ssh -o StrictHostKeyChecking=no netsim@${i} "/bin/ls -ltr /netsim/inst/ | grep erl_crash* ")

      if [[ ${ERLANG_CRASHES} == "" ]]; then
        echo -e "$i: \t INFO: No Erlang Crashes." | sed 's/^/\t\t/g'
      else
        echo -e "$i: \t ERROR: The below Erlang Crashes have occurred. Please check" | sed 's/^/\t\t/g'
        echo ${ERLANG_CRASHES} | sed 's/dump/dump\n/g' | sed 's/^/\t\t\t\t\t\t/g'
      fi
    done
  fi
}

shm_job_failures() {
  echo
  echo -e "\e[0;32mBreakdown of SHM Job Failures: \e[0m"
  echo -e "\e[0;32m==============================\e[0m"
  for i in $(${CLI_APP} 'shm status --all' | grep $(date +%d/%m/%Y) | grep FAILED | awk '{print $2}' | sort | uniq); do
    echo -e "\e[0;32m${i}\e[0m" | sed 's/^/\t/g'
    for j in $(${CLI_APP} 'shm status --all' | grep $(date +%d/%m/%Y) | grep "${i}.*FAILED" | sort -k9 | awk '{print $1}'); do
      echo -e "\e[0;35m${j}\e[0m" | sed 's/^/\t/g'
      ${CLI_APP} "shm status -jn ${j}" | egrep "Total No of Nodes|No of Nodes Completed|FAILED" | grep -v Result | sed 's/^/\t/g'
      echo
    done
    echo
    echo
  done
}

network_product_info() {
  echo
  echo -e "\e[0;32mBreakdown of neProductVersion, ossModelIdentity & nodeModelIdentity info for the network: \e[0m"
  echo -e "\e[0;32m=========================================================================================\e[0m"
  echo -e "\e[0;35mNote: Check for inconsistencies between Product Version & OssModelIdentity / nodeModelIdentity versions across each simulation.\e[0m"
  echo -e "\e[0;35mRBS Nodes\e[0m" | sed 's/^/\t/g'
  for i in $(${CLI_APP} 'cmedit get * networkelement -ne=RBS' | awk -F "=" '{print $2}' | cut -c1-24 | sort | uniq | egrep -v "^$"); do
    echo $i | sed 's/^/\t/g'
    ${CLI_APP} "cmedit get $i* networkelement.(nodeModelIdentity,neProductVersion,ossModelIdentity)  -t" | egrep -v "neProductVersion|instance|NetworkElement|^\t$" | awk '$1="";{print}' | sort | uniq -c | sort -nrk1 | sed 's/^/\t\t/g'
  done
  echo

  echo -e "\e[0;35mERBS Nodes\e[0m" | sed 's/^/\t/g'
  for i in $(${CLI_APP} 'cmedit get * networkelement -ne=ERBS' | awk -F "=" '{print $2}' | cut -c1-24 | sort | uniq | egrep -v "^$"); do
    echo $i | sed 's/^/\t/g'
    ${CLI_APP} "cmedit get $i* networkelement.(nodeModelIdentity,neProductVersion,ossModelIdentity)  -t" | egrep -v "neProductVersion|instance|NetworkElement|^\t$" | awk '$1="";{print}' | sort | uniq -c | sort -nrk1 | sed 's/^/\t\t/g'
  done
  echo

  echo -e "\e[0;35mRemainder of Network\e[0m" | sed 's/^/\t/g'
  for i in $(${CLI_APP} 'cmedit get * networkelement' | awk -F "=" '{print $2}' | cut -c1-11 | sort | uniq | egrep -v "ieatnets|NETSimI|^$" | sort); do
    echo $i | sed 's/^/\t/g'
    ${CLI_APP} "cmedit get $i* networkelement.(nodeModelIdentity,neProductVersion,ossModelIdentity)  -t" | egrep -v "neProductVersion|instance|NetworkElement|^\t$" | awk '$1="";{print}' | sort | uniq -c | sort -nrk1 | sed 's/^/\t\t/g'
  done
}

import_job_failures() {
  echo
  echo -e "\e[0;32mBreakdown of Import Job Failures: \e[0m"
  echo -e "\e[0;32m=================================\e[0m"
  for i in $(${CLI_APP} 'cmedit import -st' | egrep "$(date +%Y-%m-%d)" | cut -f1-5,13- | egrep -i "failed" | awk '{print $1}'); do
    echo -e "\e[0;32mImport Job Id ${i}\e[0m" | sed 's/^/\t/g'
    ${CLI_APP} "cmedit import -st -j $i -v" | egrep -wi "error|INVALID" | sed 's/^/\t/g'
    echo
  done
}

export_job_failures() {
  echo
  echo -e "\e[0;32mBreakdown of Export Job Failures: \e[0m"
  echo -e "\e[0;32m=================================\e[0m"
  for i in $(${CLI_APP} 'cmedit export -st' | egrep "$(date +%Y-%m-%d)" | cut -f1-5,9-11,13- | awk '$6 > 0 {print}' | awk '{print $1}'); do
    echo -e "\e[0;32mExport Job Id ${i}\e[0m" | sed 's/^/\t/g'
    ${CLI_APP} "cmedit export -st -j $i -v" | egrep -wi "NOT_EXPORTED|COMPLETED" | sed 's/^/\t/g'
    echo
  done
}

connection_db_terminated() {
  echo
  echo -e "\e[0;32mOccurrences of \"Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database\" messages:\e[0m"
  echo -e "\e[0;32m================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database" | sed "s/^/\t/g"
  echo -e "\e[0;35mCount of \"Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep -c "Connection to the database terminated" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mTotal count of \"Connection to the database terminated. This can happen due to network instabilities, or due to restarts of the database\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"Connection to the database terminated\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  #truncate -s 0 ${rv_dailychecks_tmp_file}
}

no_mediation_service() {
  echo
  echo -e "\e[0;32mOccurrences of \"No mediation service could be obtained\" messages:\e[0m"
  echo -e "\e[0;32m===================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "No mediation service could be obtained" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"No mediation service could be obtained\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "No mediation service could be obtained" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"No mediation service could be obtained\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"no_mediation_service\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

ensure_db_running() {
  echo
  echo -e "\e[0;32mOccurrences of \"ensure the database is running\" messages:\e[0m"
  echo -e "\e[0;32m=========================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "ensure the database is running" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"ensure the database is running\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "ensure the database is running" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"ensure the database is running\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"ensure the database is running\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

neo_bolt_ServiceUnavailableException() {
  echo
  echo -e "\e[0;32mOccurrences of \"Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException\" messages:\e[0m"
  echo -e "\e[0;32m=======================================================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"Exception Caught When Starting Bolt Transaction.*ServiceUnavailableException\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

no_available_threads() {
  echo
  echo -e "\e[0;32mOccurrences of \"there are no available threads to serve\" messages:\e[0m"
  echo -e "\e[0;32m==================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "there are no available threads to serve" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"there are no available threads to serve\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "there are no available threads to serve" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"there are no available threads to serve\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"there are no available threads to serve\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

mssnmpfm_isSyncronized() {
  echo
  echo -e "\e[0;32mOccurrences of \"mssnmpfm - checkHeartbeat: isSynchronized NOT-OK for node\" messages:\e[0m"
  echo -e "\e[0;32m====================================================================================\e[0m"
  zgrep -c "checkHeartbeat: isSynchronized NOT-OK for node" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
}

fm_serviceState_changes() {
  echo
  echo -e "\e[0;32mOccurrences of FMServiceStateChanges - IN_SERVICE / SYNC_ON_GOING / OUT_OF_SYNC / IN_SERVICE:\e[0m"
  echo -e "\e[0;32m=============================================================================================\e[0m"
  zgrep "currentServiceState.*for fdn" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep -oP "is changed to.* for fdn" | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
}

IdentityManagementServiceException() {
  echo
  echo -e "\e[0;32mOccurrences of \"Failed to connect to datastore.*IdentityManagementServiceException\" messages:\e[0m"
  echo -e "\e[0;32m===============================================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "Failed to connect to datastore.*IdentityManagementServiceException" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mCount of \"Failed to connect to datastore.*IdentityManagementServiceException\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  zgrep -c "Failed to connect to datastore.*IdentityManagementServiceException" /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mTotal count of \"Failed to connect to datastore.*IdentityManagementServiceException\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo
  echo -e "\e[0;35mFirst & Last occurrences of \"Failed to connect to datastore.*IdentityManagementServiceException\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | head | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | tail | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

failed_to_ping_nodes() {
  echo
  string"ping failed for node.*with error: V3 time synch fail, attempt"
  echo -e "\e[0;32mOccurrences of \"${string}: 1/2/3\" messages:\e[0m"
  echo -e "\e[0;32m========================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep ${string} >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"${string}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c ${string} | sed "s/^/\t/g"
  echo -e "\e[0;35mTotal count of \"${string}\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo -e "\e[0;35mFirst & Last occurrences of \"${string}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | head | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | tail | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

DpsAvailabilityCallbackNotifier() {
  echo
  echo -e "\e[0;32mOccurrences of \"DpsAvailabilityCallbackNotifier - DPS now available after .* of downtime\" messages:\e[0m"
  echo -e "\e[0;32m==================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "DPS now available after .* of downtime" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"DpsAvailabilityCallbackNotifier - DPS now available after .* of downtime\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "DPS now available after .* of downtime" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"DpsAvailabilityCallbackNotifier - DPS now available after .* of downtime\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mOccurrences of \"DpsAvailabilityCallbackNotifier - DPS now available after .* of downtime\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep "DPS now available after .* of downtime" | sed 's/\[com.*DPS now available/DPS now available/g' | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

DpsUnavailable() {
  string="DPS is currently unavailable. Possible disconnection to the database server"
  echo
  echo -e "\e[0;32mOccurrences of \"${string}\" messages:\e[0m"
  echo -e "\e[0;32m==================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "${string}" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"${string}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "${string}" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"${string}\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"${string}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

test () {
  echo
  echo -e "\e[0;32mOccurrences of \"${1}\" messages:\e[0m"
  echo -e "\e[0;32m==================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "${1}" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"${1}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "${1}" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"${1}\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mFirst & Last occurrences of \"${1}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | head -1 | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  echo ":" | sed "s/^/\t\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | tail -1 | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

stale_file_handle () {
  echo
  echo -e "\e[0;32mOccurrences of \"${1}\" messages:\e[0m"
  echo -e "\e[0;32m==================================================================\e[0m"
  zcat /net/${ddp_server}/data/stats/tor/LMI_${CLUSTER}/analysis/${DDP_DATE}/enmlogs/*csv.gz | grep "${1}" >${rv_dailychecks_tmp_file}
  echo -e "\e[0;35mTotal count of \"${1}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | grep -c "${1}" | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mTotal count of \"${1}\" messages per VM received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | awk -F "@" '{print $2}' | sort | uniq -c | sort -nrk1 | sed "s/^/\t/g"
  echo ""
  echo -e "\e[0;35mList of occurrences of \"${1}\" messages received on $(date +%b" "%d): \e[0m" | sed "s/^/\t/g"
  cat ${rv_dailychecks_tmp_file} | sed 's/#012/\n/g' | sed 's/#011/\t/g' | grep $(date +%Y-%m-%d) | sed "s/^/\t\t/g"
  truncate -s 0 ${rv_dailychecks_tmp_file}
}

#env_type
#test "DPS is currently unavailable. Possible disconnection to the database server"
#stale_file_handle "Stale file handle"
#DpsUnavailable
#connection_db_terminated
#DpsAvailabilityCallbackNotifier
#exit


echo
date
echo
echo "COMMENCING PHYSICAL EXTRA DAILY CHECKS NOW:"
echo "==========================================="
env_type
netsim_stopped_nodes
netsim_erlang_crashes
rollback_transactions
sps_AMOS_EntityNotFoundException_errors
solr_timeout
shm_job_failures
import_job_failures
export_job_failures
network_product_info
notification_buffer_corrupted
unprocessed_alarms_sent_northbound
unprocessed_alarms_waiting_long_time
no_active_software_version_present
no_invocation_response
Transaction_reaper
ocfstatus_request_timeouts
netconfSession_errors
queues_hanging
full_queues
full_topics
maximum_delivery_attempts
redis_bigkeys
versant_connection_pool
versant_overview
sfs_not_ready
connection_db_terminated
DpsAvailabilityCallbackNotifier
DpsUnavailable
no_mediation_service
ensure_db_running
neo_bolt_ServiceUnavailableException
no_available_threads
stale_file_handle "Stale file handle"
IdentityManagementServiceException
mssnmpfm_isSyncronized
fm_serviceState_changes
failed_to_ping_nodes
jprobe_cluster_membership_query
list_profiles
not_running_supported_profiles
profiles_to_be_updated
snapshot_overview
workload_show_alarms
echo
date
echo

rm -rf ${rv_dailychecks_tmp_file}

#MDT
#History of Model files getting deleted:
#sshvm db-3 'cat /var/log/mdt.log | grep Deleting'
#Recent history of models being deployed
#sshvm db-3 'cat /var/log/mdt.log | grep Deploying | grep -v MdtApplication | tail -10'
#Recent MmdtReport.xml files:
#du -sh /etc/opt/ericsson/ERICmodeldeployment/data/report/* | tail
#Models ready for deletion on next MDT run:
#grep modelFileForDeletion /etc/opt/ericsson/ERICmodeldeployment/data/modelFilesAvailableForDeletion/modelFilesAvailableForDeletion.xml | wc -l

# Empty PM files
# time sshvm svc-1-mspm "rop_start_time=1600;find /ericsson/pmic*/ -size 0 -type f -name [AB]20180601.${rop_start_time}"

#Get a view of what profiles have not run today
#for i in `workload status | egrep "STARTING|COMPLETED.*ERROR|COMPLETED.*WARNING|RUNNING|SLEEPING|DEAD" | awk '{print $1}'`;do for j in `ls /var/log/enmutils/daemon/ | grep -iw "${i}.log" | grep -v ".gz"`;do if [ `tail -1 /var/log/enmutils/daemon/${j} | awk '{print $1}'` = $(date +%Y-%m-%d) ]; then echo "yes";else echo -e "${i}";fi | xargs | grep -v yes;done;done

#List of inactive SHM Upgrade Packages on ERBS nodes
#cli_app 'cmedit get * upgradepackage.deletePreventingCVs -ns=ERBS_NODE_MODEL'|paste - - | awk '$NF=="[]" {print}' | egrep -v "UpgradePackage=1" | awk '{print $3}' > /var/tmp/eeialm/deletePreventingCVs.txt

#Netsim Crash Errors
#2018-08-21T10:30:19.678+01:00@svc-10-mssnmpcm@JBOSS@ERROR [com.ericsson.oss.itpf.sdk.core.retry.classic.RetryManagerNonCDIImpl] (Thread-25 (HornetQ-client-global-threads-498411219)) The maximum number of retry attempts has been reached, exception while executing command - 1552672464_58619370541801, exception - com.ericsson.oss.mediation.stn.cm.util.RetrySessionException: StartSession operation failed OperationFailed "#015#012Internal NETSim error#015#012Execution of command "startSession TCU02" crashed#015#012Crash Reason:#015#012{noproc,{gen_fsm,sync_send_all_state_event,#015#012                 [<0.615.0>,{start,"TCU02",[]},infinity]}}#015#012"#015#012#015#015#012OSmon> OperationFailed "#015#012Internal NETSim error#015#012Execution of command "upload TCU02 sftp://mm-cm_models:hka08wsu@[131.160.134.54]/smrsroot/cm_models/tcu02/K101TCU0200062.xml CM" crashed#015#012Crash Reason:#015#012{noproc,{gen_fsm,sync_send_all_state_event,[<0.615.0>,get_state,infinity]}}#015#012"#015#012#015#015#012OSmon>

#zgrep -c 'BoltTransactionTimeoutException: Server.*is no longer available' /net/ddpenm2/data/stats/tor/LMI_ENM435/analysis/131118/enmlogs/*csv.gz

#Check RadioNode product info
#for i in `cli_app 'cmedit get LTE* networkelement -ne=RadioNode'| awk -F "=" '{print $2}' | cut -c1-8 | sort | uniq`; do echo $i;cli_app "cmedit get $i* networkelement.(nodeModelIdentity,neProductVersion,ossModelIdentity)  -t" | egrep LTE | awk '$1="";{print}' | sort | uniq -c | sort -nrk1 | sed 's/^/\t/g';done

#PM Scanner status changes
#2019-04-18 05:56:38,811 INFO  [com.ericsson.oss.itpf.EVENT_LOGGER] (Thread-43670 (HornetQ-client-global-threads-1102218835)) [NO USER DATA, PMIC.SCANNER_DPS_NOTIFICATION, COARSE, DPS_NOTIFICATION, NetworkElement=RNC11MSRBS-V2319,PMICScannerInfo=PREDEF.PREDEF_Lrat.STATS, PMIC, SCANNER_POLLING, DpsScannerUpdateNotificationListener, PMICScannerInfo update notification for ScannerFdn : NetworkElement=RNC11MSRBS-V2319,PMICScannerInfo=PREDEF.PREDEF_Lrat.STATS, AttributeName : status, updated from UNKNOWN to ERROR ]
#for i in `zgrep "status.*updated from" $(ls -tr *.csv.gz|tail -1)|grep -oP "status, updated from.*" | sort | uniq`;do echo $i;zgrep "$i" $(ls -tr *.csv.gz|tail -1)| grep -oP "ScannerFdn : NetworkElement=.*," | awk -F "=" '{print $2}' | cut -c 1-8|sort | uniq -c | sort -nrk1;done

#mo_not_defined errors / These are related to edit-config requests on netsim side logging
#zgrep -i "mo_not_defined" 12_partial.csv.gz | grep -oP "ManagedElement=.*,"|sort | uniq

#Get Product Info for RadioNodes in network
#cli_app 'cmedit get RNC* networkelement -ne=RadioNode'| awk -F "=" '{print $2}' | cut -c1-8 | sort | uniq|less

# Check time periods for "databaseUnavailableError"
#[10:56:09 root@ieatwlvm7040:enmlogs ]# echo -e "\e[0;35mFROM\t\t\t\tTO\e[0m";zgrep "databaseUnavailableError" *.csv.gz |awk -F "@" '{print $1}' | sed -n -e '1p;$p' | paste - -

# Count of databaseUnavailableError reported per VM:
#[10:58:55 root@ieatwlvm7040:enmlogs ]# zgrep "databaseUnavailableError" *.csv.gz |awk -F "@" '{print $2}'|sort | uniq -c | sort -nrk1

#Top 20 Netsims with highest root space filled:
#> /var/tmp/netsim.txt;for i in {01..51}; do echo -en "ieatnetsimv5121-$i\t" >> /var/tmp/netsim.txt;ssh ieatnetsimv5121-$i 'df -hP /dev/sda2'|sed 's/^/\t/g' | grep -v Filesystem | xargs | awk '{print $(NF-1)}' >> /var/tmp/netsim.txt;done;cat /var/tmp/netsim.txt | sort -nrk2  | head -20

#Netsim root fs check
#for i in {01..51}; do echo -en "ieatnetsimv5121-$i\t";ssh ieatnetsimv5121-$i 'df -hP /dev/sda2'|sed 's/^/\t/g' | grep -v Filesystem | xargs | awk '{print $(NF-1)}';done

#Oldest prmnresponce file
#for i in {01..51}; do echo -en "ieatnetsimv5121-$i\t"; ssh ieatnetsimv5121-$i "ls -ltr /netsim/inst/prmnresponse/ | head -2 | grep -v total";done
#netsim prmn retention time
#for i in {01..51}; do echo -en "ieatnetsimv5121-$i\t"; ssh ieatnetsimv5121-$i "ls -l /netsim/.bashrc; cat /netsim/.bashrc";done

#neo debug logs - no available threads to serve it at the moment
#2019-09-19 00:00:21.429+0100 ERROR [o.n.b.r.MetricsReportingBoltConnection] Unable to schedule bolt session 'bolt-31941' for execution since there are no available threads to serve it at the moment. You can retry at a later time or consider increasing max thread pool size for bolt connector(s).

#Mediation request not processed because its flowURN could not be resolved: MediationTaskRequest

# No available neo4j threads:
#[root@vio-5625-neo4j-0 ~]# echo -e "\n\n###### Breakdown where max thread pool size on neo4j instance is reached and number of times ERROR is seen in any one minute#####\n\n";cat /ericsson/neo4j_data/logs/neo4j.log |egrep --colour 'schedule bolt session.* for execution since there are no available threads to serve it at the moment'|sed 's#ERROR Unable to schedule bolt session.*for execution since there are no available threads to serve it at the moment.*#ERROR Unable to schedule bolt session bold-id for execution since there are no available threads to serve it at the moment#g'|sed 's#:......+0000 ERROR# ERROR#g'|sort|uniq -c|sed "s/^/\t\t/g"|egrep --colour $(date +%Y-%m-%d) --colour
