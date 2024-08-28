#!/bin/bash
###############################################################
## Scrtipt: PMIC Data statistics Querying on FLSDB           ##
## Author : rajesh.chiluveru.ext@ericsson.com                ##
## Last Modified: 14-Jul-2022                                ##
###############################################################
echo -e "\e[0;34m Version: 7.4 \e[0m"
export PGPASSWORD=P0stgreSQL11
KEYPAIR="/var/tmp/enm_keypair.pem"
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
dt1=`date "+%Y-%m-%d"`
############################################
### Check PM enabled no.of nodes ###########
############################################
check_noof_nodes(){

if [ ! -f /tmp/sub_query.txt ] || [ "n$1" == "nFF" ] || [ ! -f /tmp/sub_query2.txt ] || [ ! -f /tmp/sub_query.txt1 ]
then
rm -f /tmp/sub_query.txt 
        echo -e "\e[0;33m Checking Number of Nodes.. \e[0m Takes 1-2 minutes.."
        nodes_in_system=( `$CLI_APP "cmedit get * networkelement.netype,pmFunction.pmEnabled==true"|grep neType | sort -u | awk '{print $3}'` )
if [ -z $nodes_in_system ]
then
echo " No Nodes with pmFunction ENABLED..Exiting script.."
echo
echo
exit
else
rm -f /tmp/sub_query.txt1
        for TYPE in "${nodes_in_system[@]}"
                do
                TYPE1=`echo ${TYPE}|tr -s "-" "_"`
                n_n=`$CLI_APP "cmedit get * pmfunction.pmEnabled==true -ne=${TYPE} -cn"|grep -i -v error|grep -v NetworkElement|tail -1|awk '{print $1}'`
                        if [ "2$n_n" != "2" ]
                        then
                                if [ "2$n_n" != "20" ]
                                then
                                eval "N_${TYPE1}=`echo $n_n`"
                                echo -n " when node_type like '$TYPE' then '$n_n' " >> /tmp/sub_query.txt
				echo "${TYPE}:$[N_${TYPE1}]" >> /tmp/sub_query.txt1
                                echo -e "\e[0;34m ${TYPE}:\e[0m $[N_${TYPE1}]"
                                fi
                        fi
                done
                       $CLI_APP 'cmedit get * enodebfunction -ne=RadioNode -cn'|sed -n '1p' > /tmp/sub_query2.txt
                       $CLI_APP 'cmedit get * GNBDUFunction -ne=RadioNode -cn'|sed -n '1p' >> /tmp/sub_query2.txt
                       $CLI_APP 'cmedit get * GNBCUUPFunction -ne=RadioNode -cn'|sed -n '1p' >> /tmp/sub_query2.txt
                       $CLI_APP 'cmedit get * GNBCUCPFunction -ne=RadioNode -cn'|sed -n '1p' >> /tmp/sub_query2.txt
                       $CLI_APP 'cmedit get * networkelement.radioAccessTechnology==[5G] -cn'|sed -n '1p' >> /tmp/sub_query2.txt
                grep -w ERBS /tmp/sub_query.txt >> /dev/null || echo ERBS:No >> /tmp/sub_query2.txt
		grep -w RadioNode /tmp/sub_query.txt >> /dev/null || echo RadioNode:No >> /tmp/sub_query2.txt
		$CLI_APP 'cmedit get * networkelement -ne=RNC'|grep FDN >> /dev/null
			if [ $? -eq 0 ]
			then
			$CLI_APP 'cmedit get * networkelement -ne=RNC'|awk -F"=" '{ print $2}' > /tmp/sub_query3.txt
			sed -i 's/RNC0[1-2]/33/g' /tmp/sub_query3.txt;sed -i 's/RNC0[3-4]/69/g' /tmp/sub_query3.txt;sed -i 's/RNC0[6-9]\|RNC1[0-5]/33/g' /tmp/sub_query3.txt
			sed -i 's/RNC1[6-9]\|RNC2[0-2]/69/g' /tmp/sub_query3.txt
			num_MP=`awk '{ sum += $1 } END { print sum }' /tmp/sub_query3.txt`
			echo "num_MP=${num_MP}" >> /tmp/sub_query2.txt
			rm -f /tmp/sub_query3.txt
			fi
fi
fi
}
######################################
### Verify ROP time argument #########
######################################

roptime_finder(){
if [ $# -eq 0 ] || [ "n$1" == "nFF" ]
then
_hour=`date +%H`
_minute=`date +%M`

        if [ ${_minute} -ge 0 -a ${_minute} -lt 15 ]
        then
                h1=`expr ${_hour} - 1`
                m1=30
                if [ $h1 -lt 10 ]
                then
                h1=0${h1}
                fi
        elif [ ${_minute} -ge 15 -a ${_minute} -lt 30 ]
        then
        h1=`expr ${_hour} - 1`
                if [ $h1 -lt 10 ]
                then
                h1=0${h1}
                fi

        m1=45
        elif [ ${_minute} -ge 30 -a ${_minute} -lt 45 ]
        then
        h1=${_hour}
        m1=00
        elif [ ${_minute} -ge 45 ]
        then
        h1=${_hour}
        m1=15
        fi
rop_time=${h1}:${m1}:00
echo -e "\e[0;32m Latest ROP_TIME :: \e[0m A${dt1}.${h1}:${m1}"
echo
elif [ $# -eq 2 ]
then
dt1=$1
rop_time=${2}:00
else
rop_time=$1
fi
}

##############################
## Verify ENM ISO version ####
##############################
enm_baseline(){
        echo -ne "\e[0;32m Current ENM Baseline/ISO version : \e[0m"
env|egrep 'LMS_HOST|EMP' > /tmp/entry.txt
env|egrep 'LMS_HOST|EMP' > /dev/null
if [ $? -eq 0 ]
then
        grep LMS_HOST /tmp/entry.txt  > /dev/null
        if [ $? -eq 0 ]
        then
        _ip_=`env|grep LMS_HOST|awk -F"=" '{print $2}'`
        ssh -q -t -o StrictHostKeyChecking=no ${_ip_} 'cat /etc/enm-history|tail -1'
        fi
        grep EMP /tmp/entry.txt  > /dev/null
        if [ $? -eq 0 ]
        then
        _ip_=`env|grep EMP|awk -F"=" '{print $2}'`
        ssh -q -t -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} 'sudo consul kv get "enm/deployment/enm_version"'
        fi
else
echo
echo " ERROR: LMS_HOST or EMP ip is missing on .bashrc file. Please fix it"
exit 1
fi
echo
rm -f /tmp/entry.txt
               }

#####################################
### Prepare PSQL query to run #######
#####################################
prepare_psql_query(){
echo "select node_type,start_roptime_in_oss,data_type as fileType,case" > /tmp/pmic.sql
cat /tmp/sub_query.txt >> /tmp/pmic.sql
echo "end total_nodes,count(*) as Actual,round(avg(file_size/1024),2) as file_size from pm_rop_info where start_roptime_in_oss='${dt1} ${rop_time}' and data_type not in ('PM_STATISTICAL_1MIN','PM_EBM') group by node_type,start_roptime_in_oss,data_type order by node_type,start_roptime_in_oss,data_type;" >> /tmp/pmic.sql
echo "select substring(a.rop from 1 for 29) as ROP,a.node_type,a.fcd,a.start_roptime_in_oss,a.end_roptime_in_oss,count(*),round(avg(a.kb),2) as file_size from (select split_part(file_location, '/', 6) as rop,node_type,to_char(file_creationtime_in_oss, 'yyyy-mm-dd') as fcd,start_roptime_in_oss,end_roptime_in_oss,file_size/1024 as kb from pm_rop_info where data_type='PM_STATISTICAL' and extract(epoch from (end_roptime_in_oss - start_roptime_in_oss))>=86400) a group by substring(a.rop from 1 for 29),a.node_type,a.fcd,a.start_roptime_in_oss,a.end_roptime_in_oss order by substring(a.rop from 1 for 29),a.fcd,a.node_type;" > /tmp/pmic24.sql
}
############## Status Checking ###########
ok_status_chk(){
if [ "x${1}x" == "x${2}x" ]
then
echo -e "\e[0;32mOK\e[0m"
else
echo -e "\e[0;31mNOK\e[0m"
fi
}
brown=$(printf "\033[01;33m")

######################################
### Expected PM files count     ######
######################################
expected_files_count(){
echo "`head -1 /tmp/pmic_out15`| EXPECTED | STATUS"
echo "----------------------------------------------------------------------------------------------------------------"
grep PM_ /tmp/pmic_out15|tr -d $'\r' > /tmp/pmic_out151

while read myLine
        do
        ff=`echo "$myLine"|awk -F"|" '{print $1":"$3}'|sed 's/ //g'`
        ff1=`echo "$myLine"|awk -F"|" '{print $4}'|sed 's/ //g'|tr -d $'\r'`
        ff4=`echo "$myLine"|awk -F"|" '{print $5}'|sed 's/ //g'|tr -d $'\r'`
                case "x${ff}x" in
                 "xBSC:PM_STATISTICALx"|"xMINI-LINK-Indoor:PM_STATISTICALx"|"xMINI-LINK-669x:PM_STATISTICALx")
                        ff1=`expr ${ff1} \* 4`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
		"xBSC:PM_BSC_PERFORMANCE_EVENTx")
                        if [ $ff4 -ge $ff1 ]
			then
                        sts_=`echo -e "\e[0;32mOK\e[0m"`
                        else
                        sts_=`echo -e "\e[0;31mNOK\e[0m"`
                        fi
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
			;;
                "xBSC:PM_BSC_RTTx"|"xNA:PM_BSC_RTTx")
                        if [ $ff4 -ge 1000 ]
                        then
                        sts_=`echo -e "\e[0;32mOK\e[0m"`
                        else
                        sts_=`echo -e "\e[0;31mNOK\e[0m"`
                        fi
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff4} ${sts_}
                         ;;
                "xBSC:PM_MTRx")
                        if [ $ff4 -ge $ff1 ]
                        then
                        sts_=`echo -e "\e[0;32mOK\e[0m"`
                        else
                        sts_=`echo -e "\e[0;31mNOK\e[0m"`
                        fi
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                "xEPG:PM_STATISTICALx")
                        ff1=`expr ${ff1} \* 3`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                "xSBG-IS:PM_STATISTICALx")
                        ff1=`expr ${ff1} \* 300`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                "xERBS:PM_CELLTRACEx"|"xRBS:PM_GPEHx"|"xRNC:PM_CELLTRAFFICx")
                        ff1=`expr ${ff1} \* 2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                 "xRadioNode:PM_CELLTRACEx")
			ff1=`grep -i enodebfunction /tmp/sub_query2.txt|awk '{print $2}'`
                        ff1=`expr ${ff1} \* 2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                 "xRadioNode:PM_EBSLx")
                        ff1=`grep -i enodebfunction /tmp/sub_query2.txt|awk '{print $2}'`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                 "xRadioNode:PM_CELLTRACE_DUx")
			ff1=`grep -i GNBDUFunction /tmp/sub_query2.txt|awk '{print $2}'`
                        ff1=`expr ${ff1} \* 2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                 "xRadioNode:PM_CELLTRACE_CUUPx")
			ff1=`grep -i GNBCUUPFunction /tmp/sub_query2.txt|awk '{print $2}'`
                        ff1=`expr ${ff1} \* 2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                 "xRadioNode:PM_CELLTRACE_CUCPx")
                        ff1=`$CLI_APP 'cmedit get * GNBCUCPFunction -ne=RadioNode -cn'|tail -1|awk '{print $1}'`
			ff1=`grep -i GNBCUCPFunction /tmp/sub_query2.txt|awk '{print $2}'`
                        ff1=`expr ${ff1} \* 2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                 "xRadioNode:PM_EBSN_CUCPx"|"xRadioNode:PM_EBSN_DUx"|"xRadioNode:PM_EBSN_CUUPx")
			ff1=`grep -i networkelement /tmp/sub_query2.txt|awk '{print $2}'`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                        ;;
                "xERBS:PM_UETRACEx")
			grep -w "RadioNode:No" /tmp/sub_query2.txt >> /dev/null
			if [ $? -eq 0 ]
			then
                        ff1=500
			else
			fff1=`grep ERBS: /tmp/sub_query.txt1|cut -d":" -f2`
			  if [ $fff1 -gt 480 ]
			  then
		 	  ff1=180
			  else
			  ff1=480
			  fi
                        fi
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                 "xMSC-BC-BSP:PM_STATISTICALx"|"xMSC-BC-IS:PM_STATISTICALx")
                        ff1=`expr ${ff1} \* 6`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                 "xRadioNode:PM_UETRACEx")
		  grep -w "ERBS:No" /tmp/sub_query2.txt >> /dev/null
                        if [ $? -eq 0 ]
                        then
                        ff1=500
                        else
			fff1=`grep RadioNode: /tmp/sub_query.txt1|cut -d":" -f2`
			  if [ $fff1 -gt 710 ]
			  then
			  ff1=320
			  else
                          ff1=20
                          fi
			fi
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                "xRNC:PM_UETRx")
                        ff1=`expr ${ff1} \* 16`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
                 "xRNC:PM_GPEHx")
                        ff1=`grep num_MP /tmp/sub_query2.txt |cut -d= -f2`
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                         ;;
               *)
                        sts_=`ok_status_chk ${ff4} ${ff1}`
                        echo -n " ${myLine} |"
                        /usr/bin/printf "$brown %8s | %6s \n" ${ff1} ${sts_}
                       ;;

esac
done < /tmp/pmic_out151
echo
}



######################################
### Execute PSQL query prepared ######
######################################
execute_psql_query(){
        echo -e "\e[0;33m Executing Query for 15MIN ROP \e[0m ${dt1} ${rop_time} .... "
        echo "============================================================================================"
H_name=`hostname`
############ For vENM #################

env|grep EMP > /dev/null
if [ $? -eq 0 ]
then
EMP=`env|grep EMP|cut -d"=" -f2`
Post_host=`ssh -q -t -i ${KEYPAIR} -o StrictHostKeyChecking=no cloud-user@${EMP} "sudo consul members | egrep 'postgres'"|head -1|awk '{print $1}'`
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /var/tmp/enm_keypair.pem cloud-user@${EMP}:/var/tmp/

ssh -i ${KEYPAIR} cloud-user@${EMP} "rm -f /tmp/pmic*"
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /tmp/pmic*.sql cloud-user@${EMP}:/tmp/

ssh -i ${KEYPAIR} cloud-user@${EMP} "ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host} 'sudo rm -f /tmp/pmic*'"
ssh -q -t -i ${KEYPAIR} cloud-user@${EMP} "scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /tmp/pmic*.sql cloud-user@${Post_host}:/tmp/"

ssh -i ${KEYPAIR} cloud-user@${EMP} "ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host} 'PGPASSWORD=P0stgreSQL11 /opt/rh/postgresql92/root/usr/bin/psql -h postgres -U postgres -d flsdb -f /tmp/pmic.sql -o /tmp/pmic_out15 -q'"

ssh -i ${KEYPAIR} cloud-user@${EMP} "scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host}:/tmp/pmic_out15 /tmp/"
rm -f /tmp/pmic_out15
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP}:/tmp/pmic_out15 /tmp/

expected_files_count
echo -e "\e[0;33m Total \e[0m15MIN ROP \e[0;33mPM files collected in ${dt1} ${rop_time}\e[0m :: `awk -F"|" '{ sum += $5 } END { print sum }' /tmp/pmic_out15` "
echo
echo -e "\e[0;33m Executing Query for \e[0m **24 Hr ROP** "
echo "========================================================="
ssh -i ${KEYPAIR} cloud-user@${EMP} "ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host} 'PGPASSWORD=P0stgreSQL11 /opt/rh/postgresql92/root/usr/bin/psql -h postgres -U postgres -d flsdb -f /tmp/pmic24.sql -q'"
fi

############## for CloudNative ENM ######################

if [ -f /root/.kube/config ]
then
cENM_id=`/usr/local/bin/kubectl --kubeconfig /root/.kube/config get ingress --all-namespaces | egrep ui|awk '{print $1}'`
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl cp /tmp/pmic.sql ${cENM_id}/${p_ser}:tmp/pmic.sql -c postgres -n ${cENM_id}
kubectl cp /tmp/pmic24.sql ${cENM_id}/${p_ser}:tmp/pmic24.sql -c postgres -n ${cENM_id}
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d flsdb -f /tmp/pmic.sql -o /tmp/pmic_out15 -q -n ${cENM_id}
kubectl cp ${p_ser}:tmp/pmic_out15 -c postgres /tmp/pmic_out15 -n ${cENM_id}
expected_files_count
echo "**** Total files collected in this ROP :: `cat /tmp/pmic_out15|awk -F"|" '{ sum += $5 } END { print sum }'`"
echo -e "\e[0;33m Executing Query for \e[0m **24 Hr ROP** "
echo "========================================================="
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d flsdb -f /tmp/pmic24.sql -q -n ${cENM_id}
fi

################ for Physical ENM #####################

env|grep LMS_HOST > /dev/null
if [ $? -eq 0 ]
then
LMS_H=`env|grep LMS_HOST|cut -d"=" -f2`
ser=`ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "grep postgres /etc/hosts"|awk '{print $1}'`
rm -f /tmp/pmic_out15
scp -q -o StrictHostKeyChecking=no /tmp/pmic*.sql root@${LMS_H}:/tmp/
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "PGPASSWORD=P0stgreSQL11 /usr/bin/psql -h ${ser} -U postgres -d flsdb -f /tmp/pmic.sql -o /tmp/pmic_out15 -q"
scp -q -o StrictHostKeyChecking=no root@${LMS_H}:/tmp/pmic_out15 /tmp/pmic_out15
expected_files_count

echo -e "\e[0;33m Total \e[0m15MIN ROP \e[0;33mPM files collected in ${dt1} ${rop_time}\e[0m :: `awk -F"|" '{ sum += $5 } END { print sum }' /tmp/pmic_out15` "
echo
echo -e "\e[0;33m Executing Query for \e[0m **24 Hr ROP** "
echo "========================================================="
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "PGPASSWORD=P0stgreSQL11 /usr/bin/psql -h ${ser} -U postgres -d flsdb -f /tmp/pmic24.sql -q"
fi
        echo -e "\e[0;33m ********** END of QUERY Execution *********** \e[0m"
}
#######################
## Main       #########
#######################
if [ $# -ge 1 ]
 then
   if [ `echo $1|wc -c` -eq 6 ]
   then
   rop_time=$1
   echo -e "\e[0;32m Checking for ROP_TIME :: \e[0m A${dt1}.${1}"
        echo
      _hourm=`date +%H%M`
      _hourm1=`echo $1|sed 's/://'`
      if [ ${_hourm1} -ge ${_hourm} ]
         then
         echo
         echo " ERROR :: ROP_TIME is MORE than current time .. "
         exit
      fi
   fi
   if [ $# -eq 2 ]
   then
   dt1=$1
   rop_time=$2
   elif [ "n$1" == "nFF" ]
   then
roptime_finder $1
#enm_baseline
check_noof_nodes $1
rm -f /tmp/pmic*
prepare_psql_query
execute_psql_query
exit
elif [ `echo $1|wc -c` -ne 6 -o $# -gt 1 ]
   then
   echo
   echo "  Syntax ERROR .. !!! "
   echo -e "\e[0;32m  Script Help - Run script as follows with no parameters OR with ROP_TIME parameter eg:10:15 OR date & ROP combination eg: 2019-08-17 10:15  \e[0m"
   echo -e "\e[0;35mPRE-REQUISITES for physical/vENM/VIO/cENM deployments: \e[0m"| sed "s/^/\t/g"
   echo "1). For *vENM* Ensure .pem key file is on WORKLOAD VM.  if applicable.."| sed "s/^/\t/g"
   echo "2). For *physical* Ensure LMS_HOST ip (for physical) OR EMP VM ip (for vENM/vio) present in .bashrc file on WORKLOAD VM."| sed "s/^/\t/g"
   echo "3). For *cENM* Ensure kube config file is present on WORKLOAD VM."| sed "s/^/\t/g"
   echo
   exit 1
   fi
fi

###########################
### Call to functions #####
###########################
roptime_finder $1 $2
#enm_baseline
check_noof_nodes
rm -f /tmp/pmic*
prepare_psql_query
execute_psql_query
