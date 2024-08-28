#!/bin/bash
#################################################################
### Scrtipt: PMIC Data statistics using FLSDB                 ###
### Author : rajesh.chiluveru.ext@ericsson.com                ###
### Last Modified: 27-June-2022                               ###
#################################################################
echo -e "\e[0;34m Version: 7.3\e[0m"
_Str1=`date +%d%m%y%H_%M_%S`
rm -f /tmp/fls*
rm -f /tmp/ERAHCHU/ERAHCHU_fls_dump.txt*
rm -f /tmp/ERAHCHU/fls_*
rm -f /tmp/ERAHCHU/rop*
rm -f /tmp/ERAHCHU/Missed*
rm -f /tmp/ERAHCHU/Duplicate*
######################
## Help           ####
######################
_cha_=`echo "$2$3$4"|wc -c`
if [ $# -ne 4 ]
   then
   echo "  Syntax ERROR .. !!! "
   echo -e "\e[0;32m  Script Help - Run script as follows with parameters \e[0m **For physical, run script from LMS_HOST**"
   echo -e "\e[0;32m  ./PM_missed.sh MINI-LINK-Indoor <date in yyyymmdd> <ROP_start_hour> <ROP_end_hour> \e[0m"
   echo -e "\e[0;33m  ./PM_missed.sh MINI-LINK-Indoor 20191004 03 04 \e[0m"
   echo -e "\e[0;35mPRE-REQUISITES for physical/vENM/VIO/cENM deployments: \e[0m"| sed "s/^/\t/g"
   echo "1). For *vENM* Ensure .pem key file is on WORKLOAD VM.  if applicable.."| sed "s/^/\t/g"
   echo "2). For *physical* Ensure LMS_HOST ip (for physical) OR EMP VM ip (for vENM/vio) present in .bashrc file on WORKLOAD VM."| sed "s/^/\t/g"
   echo "3). For *cENM* Ensure kube config file is present on WORKLOAD VM."| sed "s/^/\t/g"
   echo
   exit 1
fi
if [ ${_cha_} -ne 13 ]
        then
        echo "  Syntax ERROR .. !!! "
        exit 1
fi

export PGPASSWORD=P0stgreSQL11
KEYPAIR="/var/tmp/enm_keypair.pem"
CLI_APP="/opt/ericsson/enmutils/bin/cli_app"
red=$(printf "\033[01;31m")
blue=$(printf "\033[01;34m")
green=$(printf "\033[01;32m")
whte=$(printf "\033[01;37m")
mkdir -p /tmp/ERAHCHU/

if [ ! -f "/tmp/ERAHCHU/node${1}_fqdn_dump.txt" ]
then
        echo " ** Generating node list/dump for $1 NodeType .. "
        $CLI_APP "cmedit get * managedelement -ne=$1" > /tmp/ERAHCHU/fqdn.txt
	cat /tmp/ERAHCHU/fqdn.txt|grep -i error >> /dev/null	
	if [ $? -eq 0 ] ; then echo "WARNING: NodeType $1 does not have ManagedElement MO ...";fi
	cat /tmp/ERAHCHU/fqdn.txt|awk '{print $3}'|sed '/^$/d'  > /tmp/ERAHCHU/node${1}_fqdn_dump.txt
        grep -i managedelement /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /dev/null
                if [ $? -ne 0 ]
                then
                $CLI_APP "cmedit get * networkelement -ne=$1"|awk '{print $3}'|sed '/^$/d'  > /tmp/ERAHCHU/node${1}_fqdn_dump.txt
                sed -i 's/NetworkElement/SubNetwork=Europe,SubNetwork=Ireland,SubNetwork=NETSimW,ManagedElement/g' /tmp/ERAHCHU/node${1}_fqdn_dump.txt
                fi
        echo " ** Done .. "
case "x${1}x" in
        xMINI-LINK-Indoorx|xMINI-LINK-669xx)
                sed 's/$/_ethernet/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt  > /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_ethsoam/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_continuous/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sort -u /tmp/ERAHCHU/${1}_DUMP > /tmp/ERAHCHU/${1}_1DUMP
                ;;
        xRBSx|xERBSx)
                sed -i 's/,ManagedElement=1//g' /tmp/ERAHCHU/node${1}_fqdn_dump.txt
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sort -u /tmp/ERAHCHU/${1}_DUMP > /tmp/ERAHCHU/${1}_1DUMP
                ;;
        xBSCx)
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt > /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sort /tmp/ERAHCHU/${1}_DUMP > /tmp/ERAHCHU/${1}_1DUMP
                ;;
        xEPGx)
                sed 's/$/_sgw/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt > /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_node/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sed 's/$/_pgw/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sort /tmp/ERAHCHU/${1}_DUMP > /tmp/ERAHCHU/${1}_1DUMP
                ;;

        *)
                sed 's/$/_statsfile/' /tmp/ERAHCHU/node${1}_fqdn_dump.txt >> /tmp/ERAHCHU/${1}_DUMP
                sort /tmp/ERAHCHU/${1}_DUMP > /tmp/ERAHCHU/${1}_1DUMP
                ;;
esac

fi


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

######################################
### Execute PSQL query prepared ######
######################################
execute_FLS_query(){
_Str1=`echo $1`


############# for vENM & VIO ENM #################
env|grep EMP > /dev/null
if [ $? -eq 0 ]
then
EMP=`env|grep EMP|cut -d"=" -f2`
Post_host=`ssh -q -t -i ${KEYPAIR} -o StrictHostKeyChecking=no cloud-user@${EMP} "sudo consul members | egrep 'postgres'"|head -1|awk '{print $1}'`
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /tmp/ERAHCHU/fls_query.sql${_Str1} cloud-user@${EMP}:/tmp/
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /var/tmp/enm_keypair.pem cloud-user@${EMP}:/var/tmp/
ssh -q -t -i ${KEYPAIR} cloud-user@${EMP} "scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} /tmp/fls_query.sql${_Str1} cloud-user@${Post_host}:/tmp/"
ssh -q -t -i ${KEYPAIR} cloud-user@${EMP} "ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host} 'PGPASSWORD=P0stgreSQL11 /opt/rh/postgresql92/root/usr/bin/psql -U postgres -d flsdb -f /tmp/fls_query.sql${_Str1} -o /tmp/fls_dump.txt${_Str1} -q'"
ssh -q -t -i ${KEYPAIR} cloud-user@${EMP} "scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${Post_host}:/tmp/fls_dump.txt${_Str1} /tmp/"
rm -f /tmp/ERAHCHU_fls_dump.txt${_Str1}
scp -q -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP}:/tmp/fls_dump.txt${_Str1} /tmp/ERAHCHU/ERAHCHU_fls_dump.txt${_Str1}
fi


############## for CloudNative ENM ######################
if [ -f /root/.kube/config ]
then
cENM_id=`/usr/local/bin/kubectl --kubeconfig /root/.kube/config get ingress --all-namespaces | egrep ui|awk '{print $1}'`
p_ser=`/usr/local/bin/kubectl get pod -n ${cENM_id} -L role|grep postgres|grep master|awk '{print $1}'`
kubectl -n ${cENM_id} cp /tmp/ERAHCHU/fls_query.sql${_Str1} ${cENM_id}/${p_ser}:tmp/fls_query.sql${_Str1} -c postgres 
rm -f /tmp/ERAHCHU/ERAHCHU_fls_dump.txt*
kubectl exec -it ${p_ser} -c postgres -n ${cENM_id} -- /usr/bin/psql -U postgres -d flsdb -f /tmp/fls_query.sql${_Str1} -o /tmp/ERAHCHU_fls_dump.txt${_Str1} -q
kubectl -n ${cENM_id} cp ${p_ser}:tmp/ERAHCHU_fls_dump.txt${_Str1} -c postgres /tmp/ERAHCHU/ERAHCHU_fls_dump.txt${_Str1}
fi



############ For physical ENM #################
env|grep LMS_HOST > /dev/null
if [ $? -eq 0 ]
then
LMS_H=`env|grep LMS_HOST|cut -d"=" -f2`
ser=`ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "grep postgres /etc/hosts"|awk '{print $1}'`
scp -q -o StrictHostKeyChecking=no /tmp/ERAHCHU/fls_query.sql${_Str1} root@${LMS_H}:/tmp/
rm -f /tmp/ERAHCHU/ERAHCHU_fls_dump.txt*
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "PGPASSWORD=P0stgreSQL11 /usr/bin/psql -h ${ser} -U postgres -d flsdb -f /tmp/fls_query.sql${_Str1} -o /tmp/ERAHCHU_fls_dump.txt${_Str1} -q"
scp -q -o StrictHostKeyChecking=no root@${LMS_H}:/tmp/ERAHCHU_fls_dump.txt${_Str1} /tmp/ERAHCHU/
fi
}

######################################
### Duplicate/Missed check      ######
######################################
dup_mis_check(){
if [ $1 -gt 0 ] ; then grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep "$2"|cut -d"/" -f2|sed 's/,ManagedElement=1//g'|awk -F"=" '{print $NF}'|cut -d"." -f1|sort > /tmp/node2.txt;comm -23 /tmp/node1.txt /tmp/node2.txt|sed 's/$/_MISS/'; fi
if [ $1 -lt 0 ] ; then grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep "$2"|cut -d"/" -f2|sed 's/,ManagedElement=1//g'|awk -F"=" '{print $NF}'|cut -d"." -f1|sort > /tmp/node2.txt;comm -23 /tmp/node2.txt /tmp/node1.txt|sed 's/$/_DUP/'; fi
}


######################################
### Process output              ######
######################################

process_File(){
_Str1=`echo $3`
egrep 'XML|asn' /tmp/ERAHCHU/ERAHCHU_fls_dump.txt${_Str1}|awk -F"/" '{print $(NF-1)"/"$NF}' > /tmp/ERAHCHU/fls_dump.txt${_Str1}1
awk -F"/" '{print $NF}' /tmp/ERAHCHU/fls_dump.txt${_Str1}1|cut -c1-24|sort -u > /tmp/ERAHCHU/rops.txt${_Str1}
if [ -s /tmp/ERAHCHU/rops.txt${_Str1} ]
then
   if [ "x${1}x" == "xMINI-LINK-Indoorx" -o "x${1}x" == "xMINI-LINK-669xx" ]
       then
		sort -u /tmp/ERAHCHU/node${1}_fqdn_dump.txt|awk -F"=" '{print $NF}' > /tmp/node11.txt
                while read line1
                do
		_nfiles_=`grep -c ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1`
	        _nstat_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep -c "statsfile.xml.gz"`
                _mstat_=`expr ${4} - ${_nstat_}`
		_ncont_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep -c statsfile_continuous`
                _mcont_=`expr ${4} - ${_ncont_}`
                _nether_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep -c ethernet`
                _mether_=`expr ${4} - ${_nether_}`
                _nethso_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|grep -c ethsoam`
                _methso_=`expr ${4} - ${_nethso_}`
		_noor_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|awk '{ sum += $NF } END { print (sum) }'`
		dup=0;msd=0;for zz in $_mstat_ $_mcont_ $_mether_ $_methso_
		do
			if [ ${zz} -lt 0 ]
			then
			dup=`expr $dup + ${zz}`
			elif [ ${zz} -gt 0 ]
			then
			msd=`expr $msd + ${zz}`
			fi
		done
/usr/bin/printf "%-26s | %-12s | %6s($red%4s$whte) | %6s($red%4s$whte) | %6s($red%4s$whte) | %6s($red%4s$whte) | %-12s | %-12s | %-12s\n" $line1 $_nfiles_ $_ncont_ $_mcont_ $_nstat_ $_mstat_ $_nether_ $_mether_ $_nethso_ $_methso_ $msd $dup $_noor_
		sed 's/$/_statsfile/' /tmp/node11.txt|sort > /tmp/node1.txt
		dup_mis_check ${_mstat_} statsfile.xml.gz $1 > /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}
		sed 's/$/_statsfile_continuous/' /tmp/node11.txt|sort > /tmp/node1.txt
		dup_mis_check ${_mcont_} continuous $1 >> /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}
		sed 's/$/_statsfile_ethernet/' /tmp/node11.txt|sort > /tmp/node1.txt
		dup_mis_check ${_mether_} ethernet $1 >> /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}
		sed 's/$/_statsfile_ethsoam/' /tmp/node11.txt|sort > /tmp/node1.txt
		dup_mis_check ${_methso_} ethsoam $1 >> /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}
        	n_m=`cat /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}|wc -l`
	if [ ${n_m} -gt 0 -a ${n_m} -le 10 ]
	then
        echo -e "\e[0;31m Missed/Duplicate Files/rows on FLS in $line1 ROP :\e[0m manually Cross check in pmic1/pmic2 dir to confirm"
        cat /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}|tr -s "\n" ";"|sed 's/_MISS/\x1B[31m_MISS\x1B[0m/g;s/_DUP/\x1B[32m_DUP\x1B[0m/g'
	echo
        elif [ ${n_m} -gt 10 ]
	then
        echo -e "\e[0;31m Missed/Duplicate Files/rows on FLS in $line1 ROP :\e[0m Check in /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1} FILE"
        fi
		done < /tmp/ERAHCHU/rops.txt${_Str1}
  else
        	cat /tmp/ERAHCHU/node${1}_fqdn_dump.txt|sed 's/,ManagedElement=1//g'|sort |awk -F"=" '{print $NF}' > /tmp/node11.txt
		while read line1
        	do
	        _nfiles_=`grep -c ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1`
        	_misd_=`expr $2 - $_nfiles_`
	        _nstat_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|egrep -c "statsfile.xml|statsfile.asn|_statsfile_"`
        	_noor_=`grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|awk '{ sum += $NF } END { print (sum) }'`
	        grep ${line1} /tmp/ERAHCHU/fls_dump.txt${_Str1}1|sed -n 's/\(.*\)\/.*_\(.*_\?.*\)\.\a\?s\?n\?1\?x\?m\?l\?\.\?g\?z\?.*/\1_\2/p' > /tmp/ERAHCHU/fls_node1.txt${_Str1}
        	sed -i 's/.xml//g' /tmp/ERAHCHU/fls_node1.txt${_Str1}
	        sort /tmp/ERAHCHU/fls_node1.txt${_Str1} > /tmp/ERAHCHU/fls_node1.txt${_Str1}2
		/usr/bin/printf "%-26s | %-11s | %-11s | %-11s | %-11s\n" ${line1} $_nfiles_ $_nstat_ $_misd_ $_noor_
		sed 's/$/_statsfile/' /tmp/node11.txt|sort > /tmp/node1.txt
		dup_mis_check ${_misd_} statsfile $1 > /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}
                n_m=`cat /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}|wc -l`
        if [ ${n_m} -gt 0 -a ${n_m} -le 10 ]
        then
        echo -e "\e[0;31m Missed/Duplicate Files/rows on FLS in $line1 ROP :\e[0m manually Cross check in pmic1/pmic2 dir to confirm"
        cat /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1}|tr -s "\n" ";"|sed 's/_MISS/\x1B[31m_MISS\x1B[0m/g;s/_DUP/\x1B[32m_DUP\x1B[0m/g'
        echo
        elif [ ${n_m} -gt 10 ]
	then
        echo -e "\e[0;31m Missed/Duplicate Files/rows on FLS in $line1 ROP :\e[0m Check in /tmp/ERAHCHU/MissedOrDup_Nodes_${1}_${_Str1}_${line1} FILE"
        fi

		done < /tmp/ERAHCHU/rops.txt${_Str1}
  fi
_n_rops=`cat /tmp/ERAHCHU/rops.txt${_Str1}|wc -l`
if [ ${_n_rops} -lt 4 ]
then
echo "<<** ALERT **>> :: 1 or more ROPs missed Data. IGNORE if NSS-UG on the Day "
fi
echo -e "\e[0;33m --------------------------------------------------------------------------\e[0m"
fi
}

######################################
### MAIN Programm               ######
######################################

#enm_baseline
_n_tot=`$CLI_APP "cmedit get * pmfunction.pmEnabled==true -ne=$1 -cn"|grep -i -v error|grep -v NetworkElement|tail -1|awk '{print $1}'`
                        if [ "2${_n_tot}" != "2" ]
                        then
                                if [ "2${_n_tot}" = "20" ]
                                then
                                echo " ERROR: Failed to get No.of PmFunction enabled nodes using cli_app "
                                exit 1
                                fi
                        fi

case "x${1}x" in
        xMSC-BC-BSPx)
                _n_tot1=`echo "${_n_tot}*6"|bc`
                ;;
        xMSC-BC-ISx)
                _n_tot1=`echo "${_n_tot}*6"|bc`
                ;;
        xMINI-LINK-Indoorx|xMINI-LINK-669xx)
                _n_tot1=`echo "${_n_tot}*4"|bc`
                ;;
        xBSCx)
                _n_tot1=`echo "${_n_tot}*4"|bc`
                ;;
        xEPGx)
                _n_tot1=`echo "${_n_tot}*3"|bc`
                ;;
        xSBG-ISx)
                _n_tot1=`echo "${_n_tot}*300"|bc`
                ;;
        *)
        _n_tot1=`echo "${_n_tot}"`
                ;;
esac


        if [ "x${1}x" == "xMINI-LINK-Indoorx" -o "x${1}x" == "xMINI-LINK-669xx" ]
        then
        echo -e "\e[0;33m Total No.of PM files expected per ROP for $1 nodeType:: \e[0m ${_n_tot1} "
        /usr/bin/printf "$blue%-26s | %12s | %12s | %12s | %12s | %12s | %12s | %12s | %-12s\n" "DATE_ROP" "TOTAL_FILES" "CONTINUOUS" "STATISTICAL" "ETHERNET" "ETHSOAM" "MISSED#" "DUPLICATE#" "OutofROP#"
        else
        echo -e "\e[0;33m Total No.of PM files expected per ROP for $1 nodeType:: \e[0m ${_n_tot1} "
        /usr/bin/printf "$blue%-26s | %11s | %11s | %11s | %-11s\n" "DATE_ROP" "TOTAL_FILES" "STATISTICAL" "MISSED#" "OutofROP#"
        fi
echo -e "\e[0;33m --------------------------------------------------------------------------\e[0m"
                for _H1_ in $(eval echo "{$3..$4}")
                do
#               echo "select file_location from pm_rop_info where node_type='${1}' and data_type='PM_STATISTICAL' and file_location like '%${2}.${_H1_}+${_tz_}-%';" > /tmp/ERAHCHU/fls_query.sql${_Str1}
echo "select file_location,( case when file_creationtime_in_oss > (end_roptime_in_oss + (15 ||' minutes')::interval) then 1 else 0 END ) as out  from pm_rop_info where node_type='${1}' and data_type='PM_STATISTICAL' and file_location like '%${2}.${_H1_}%${_tz_}-%';" > /tmp/ERAHCHU/fls_query.sql${_Str1}

                execute_FLS_query ${_Str1}
                process_File $1 ${_n_tot1} ${_Str1} ${_n_tot}
                done
