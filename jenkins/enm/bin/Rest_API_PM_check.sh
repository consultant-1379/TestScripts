#!/bin/bash
###############################################################
## Script: PMIC Data statistics using FLS REST API          ##
## Author : rajesh.chiluveru@ericsson.com                    ##
## Last Modified: 29-Jan-2019                                ##
###############################################################
echo -e "\e[0;34m Version: 5.2 \e[0m"
ofs_=`date '+%z'`
######################
## Help           ####
######################
_cha_=`echo "$2$3$4"|wc -c`
if [ $# -ne 4 ]
   then
   echo "  Syntax ERROR .. !!! "
   echo -e "\e[0;32m  Script Help - Run script as follows with parameters \e[0m **For physical, run script from LMS_HOST**"
   echo -e "\e[0;32m  ./Rest_API_PM_check.sh <nodeType> <date in yyyymmdd> <ROP_start_hour> <ROP_end_hour> \e[0m"
   echo -e "\e[0;33m  ./Rest_API_PM_check.sh MINI-LINK-669x 20191004 03 04 \e[0m"
   echo -e "\e[0;35mPRE-REQUISITES for physical/vENM/VIO deployments: \e[0m"| sed "s/^/\t/g"
   echo "1). Ensure .pem key (for vENM/vio) file is on WORKLOAD VM."| sed "s/^/\t/g"
   echo "2). Ensure ENM_URL variable is set in .bashrc on workload vm"| sed "s/^/\t/g"
   echo "3). Ensure LMS_HOST ip (for physical) OR EMP VM ip (for vENM/vio) present in .bashrc file on WORKLOAD VM."| sed "s/^/\t/g"
   echo
   exit 1
fi
if [ ${_cha_} -ne 13 ]
then
echo "  Syntax ERROR .. !!! "
exit 1
fi

KEYPAIR="/var/tmp/enm_keypair.pem"
_enm_url=`env|grep ENM_URL|awk -F"=" '{print $2}'`
env|grep ENM_URL >> /dev/null
if [ $? -ne 0 ]
 then
 echo "ERROR: ENM_URL is missing in .bashrc file. Please add .."
 exit 1
fi

env|grep EMP > /dev/null
if [ $? -eq 0 ]
then
EMP=`env|grep EMP|cut -d"=" -f2`
ssh -q -t -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -X POST -k -c /tmp/erahchu_adminCookie2 'https://${_enm_url}:443/login?IDToken1=administrator&IDToken2=TestPassw0rd'"
  if [ $? -ne 0 ]
  then
  echo "Failed to create Cookie file"
  exit 1
  fi
fi

env|grep LMS_HOST > /dev/null
if [ $? -eq 0 ]
then
LMS_H=`env|grep LMS_HOST|cut -d"=" -f2`
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -X POST -k -c /tmp/erahchu_adminCookie2 'https://${_enm_url}:443/login?IDToken1=administrator&IDToken2=TestPassw0rd'"
 if [ $? -ne 0 ]
  then
  echo "Failed to create Cookie file"
  exit 1
 fi
fi

rm -f /tmp/erahchu_PM_fls_data.txt*

_Str=`date +%d%m%y%H_%M_%S`


################################
### Procedure definition #######
################################
text_process(){
grep fileLocation /tmp/erahchu_PM_fls_data.txt_${_Str} >> /dev/null
if [ $? -eq 0 ]
then
sed -i 's/"//g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/[][]//g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/{nodeType:/\n/g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/{files://g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/,dataType:/ /g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/,fileLocation:/ /g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/},//g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i '/^nodeType:/d' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's/}//g' /tmp/erahchu_PM_fls_data.txt_${_Str}
awk -F"/" '{print $1$NF}' /tmp/erahchu_PM_fls_data.txt_${_Str} > /tmp/erahchu_PM_fls_data.txt_${_Str}1
mv /tmp/erahchu_PM_fls_data.txt_${_Str}1 /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i 's@\(.*\) \(.*\) .*[A-Z]\([0-9]\+\.[0-9]\++[0-9]\+\-[0-9]\+\?\.\?[0-9]\++[0-9]\+\)_.*_\(.*_\?.*\)\.\a\?s\?n\?1\?x\?m\?l\?\.\?g\?z\?.*@\1 \2_\4 \3@g' /tmp/erahchu_PM_fls_data.txt_${_Str}
sed -i '/^$/d' /tmp/erahchu_PM_fls_data.txt_${_Str}
sort -u /tmp/erahchu_PM_fls_data.txt_${_Str} > /tmp/erahchu_PM_fls_data.txt_${_Str}1
while read _line_
do
_nt_=`echo "${_line_}"|cut -d" " -f1`
_dt_=`echo "${_line_}"|cut -d" " -f2`
_srt_=`echo "${_line_}"|cut -d" " -f3`
_cntof_=`grep -c "${_line_}" /tmp/erahchu_PM_fls_data.txt_${_Str}`
/usr/bin/printf "%-18s | %-31s | %-18s | %-10s\n" $_nt_ $_dt_ $_srt_ $_cntof_
done < /tmp/erahchu_PM_fls_data.txt_${_Str}1
else
echo
echo " ERROR: No data fetched further with given arguments/Filter. Please cross check NodeType/Start-End hour..!!"
exit 1
fi
}

###################################
## REST API query execution #######
###################################
_procedure_rest(){
echo -e "\e[0;33m !!.. Please Wait ..!!, It takes less than a minute \e[0mExecuting REST API Query ..... "
for _h1_ in $(eval echo "{$3..$4}")
do
env|grep EMP > /dev/null
if [ $? -eq 0 ]
then
EMP=`env|grep EMP|cut -d"=" -f2`
        if [ "x${1}x" == "xMINI-LINK-Indoorx" -o "x${1}x" == "xMINI-LINK-669xx" ]
        then
        rm -f /tmp/erahchu_PM_fls_data.txt_${_Str}
                for _ropTime_ in 00 15 30 45
                do
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile.xml.gz' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_continuous.xml.gz' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_ethernet.xml.gz' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_ethsoam.xml.gz' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
                done
                        else
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}00${ofs_}-*' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}15${ofs_}-*' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}30${ofs_}-*' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -o StrictHostKeyChecking=no -i ${KEYPAIR} cloud-user@${EMP} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}45*${ofs_}-' --data-urlencode 'select=nodeType,dataType,fileLocation'" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
        fi
fi

env|grep LMS_HOST > /dev/null
if [ $? -eq 0 ]
then
LMS_H=`env|grep LMS_HOST|cut -d"=" -f2`
        if [ "x${1}x" == "xMINI-LINK-Indoorx" -o "x${1}x" == "xMINI-LINK-669xx" ]
        then
        rm -f /tmp/erahchu_PM_fls_data.txt_${_Str}
                for _ropTime_ in 00 15 30 45
                do
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile.xml.gz' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_continuous.xml.gz' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_ethernet.xml.gz' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}${_ropTime_}${ofs_}-*_statsfile_ethsoam.xml.gz' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
                done
        else
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}00${ofs_}-*' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}15${ofs_}-*' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}30${ofs_}-*' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
ssh -q -t -o StrictHostKeyChecking=no ${LMS_H} "curl -s -G --insecure --cookie /tmp/erahchu_adminCookie2 --request GET 'https://${_enm_url}/file/v1/files' --data-urlencode 'filter=dataType==PM_STATISTICAL;nodeType==$1;fileLocation==*${2}.${_h1_}45${ofs_}-*' --data-urlencode select=nodeType,dataType,fileLocation" > /tmp/erahchu_PM_fls_data.txt_${_Str}
text_process
        fi
fi
echo -e "\e[0;33m ---------------------------------------------------------------------------- \e[0m"
done
}

#######################
## Procedure call #####
#######################
_procedure_rest $1 $2 $3 $4
