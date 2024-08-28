#!/bin/bash
###############################################################
## Scrtipt: PMIC Data statistics Querying on pmserv VM       ##
## Author : rajesh.chiluveru@ericsson.com                                ##
## Last Modified: 20-Nov-2017                                ##
###############################################################
mkdir -p /tmp/erahchu_scripts
svm=/root/rvb/bin/ssh_to_vm_and_su_root.exp
KEYPAIR=/var/tmp/enm_keypair.pem

if [ $# -ne 0 ]
then
echo
echo "Syntax Error ...."
echo "Usage: ./15mnt_PM_data.sh "
echo " Eg  : ./15mnt_PM_data.sh "
echo
exit
fi

date_format=`date "+%Y-%m-%d"`

 H_name=`hostname`
 echo ${H_name}|grep wlvm > /dev/null

#     if [ $? -eq 0 ]
#     then
#EMP=`cat ~/.bashrc|grep EMP|cut -d"=" -f2`
#grep EMP ~/.bashrc > /dev/null
#if [ $? -ne 0 ]
#then
#echo "ERROR:: "
#echo " EMP vm IP address is NOT present in .bashrc file .."
#echo
#exit
#fi
rm -f /tmp/erahchu_scripts/total.txt

#for name_VM in `ssh -i ${KEYPAIR} cloud-user@${EMP} "/usr/bin/consul members|grep pmserv"|awk '{print $1}'|tr -s "\n" " "`
#do
#ssh -i ${KEYPAIR} cloud-user@${EMP} "ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${name_VM} 'grep fifteenMinuteRopFileCollectionCycleInstrumentation /ericsson/3pp/jboss/standalone/log/server.log*'" >> /tmp/erahchu_scripts/total.txt
#done
for name_VM in `kubectl get pods | grep pmserv| awk '{print $1}'`
do
kubectl exec -it $name_VM -n enm201 -- grep fifteenMinuteRopFileCollectionCycleInstrumentation  /ericsson/3pp/jboss/standalone/log/server.log >> /tmp/erahchu_scripts/total.txt
done
#     else
#rm -f /tmp/erahchu_scripts/total.txt
#for name_VM in `grep pmserv /etc/hosts|awk '{print $2}'|tr -s "\n" " "`
#do
#     $svm ${name_VM} 'grep fifteenMinuteRopFileCollectionCycleInstrumentation /ericsson/3pp/jboss/standalone/log/server.log*' >> /tmp/erahchu_scripts/total.txt
#done
    #fi

cat /tmp/erahchu_scripts/total.txt|grep $date_format|grep -v "1970-01-01"|sort -n -k 1,2 > /tmp/erahchu_scripts/totallines.txt

echo "===================================================================================="
printf '%-17s %-15s %-10s %-10s\n' ROP_START_TIME DATA_TRANSFERED_MB FILES_COLLECTED FILES_FAILED
echo "===================================================================================="

while read line
do
v1=`echo ${line} |cut -d, -f14|cut -d= -f2|cut -c1-10`
if [ $v1 -eq 0 ]
then
c1=`echo ${line} |cut -d, -f1|awk -F":" '{print $1":"$2}'`
else
c1=`date -d @$v1 "+%Y-%m-%d %H:%M"`
fi
v2=`echo ${line} |cut -d, -f15|cut -d= -f2|cut -c1-10`
c2=`date -d @$v1 "+%Y-%m-%d %H:%M"`
v3=`echo ${line} |cut -d, -f12|cut -d= -f2`
c3=`echo "scale=3;$v3/1024/1024"|bc`
c4=`echo ${line} |cut -d, -f10|cut -d= -f2`
c5=`echo ${line} |cut -d, -f11|cut -d= -f2`
#printf '%-17s %10s %16s %10s\n' "ROP_START_TIME:$c1" "DATA_TRANSFERED_MB:$c3" "$c4" "$c5"
echo -e "ROP_START_TIME: \e[0;33m$c1 \e[0m DATA_TRANSFERED_MB: \e[0;33m$c3 \e[0mFILES_COLLECTED: \e[0;33m$c4 \e[0mFILES_FAILED: \e[0;31m$c5 \e[0m"
done < /tmp/erahchu_scripts/totallines.txt
rm -f /tmp/erahchu_scripts/total.txt /tmp/erahchu_scripts/totallines.txt