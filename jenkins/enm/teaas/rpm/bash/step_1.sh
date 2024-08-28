#!/bin/bash

######## CONFIG ################

ENM_SERVICES_DIR="/var/www/html/ENM_services"
DEPLOYMENT_ID=$1
RPM_URL=$2
MSIP=`wget -q -O - --no-check-certificate "https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId=${DEPLOYMENT_ID}&tunnel=true" | awk -F',' '{print $1}' | awk -F':' '{print $2}' | sed -e "s/\"//g" -e "s/ //g"`
RPM_NAME=`echo ${RPM_URL} | awk -F"/" '{print $NF}'`
RPM_NAME_SPLIT=`echo ${RPM_NAME}  | awk -F '-' '{print $1}'`

################################

#Check ssh connection
CHECK_SSH_CONNECTION=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP}`
CHECK_SSH_CONNECTION_EXIT_CODE=`echo $?`
if [[ $CHECK_SSH_CONNECTION_EXIT_CODE != 0 ]]
then
		echo '{"LEVEL":"ERROR","MESSAGE":"Cannot ssh to LMS"}';
		exit;
fi

#Check Deployment ID
if [[ $DEPLOYMENT_ID == "" || $DEPLOYMENT_ID == "undefined"  ]]
then
	echo '{"LEVEL":"ERROR","MESSAGE":"Deployment ID is not set"}';
	exit;
fi

#Check rpm exists
URL_IS_VALID=`wget --spider $RPM_URL;echo $?`

if [[ $URL_IS_VALID != 0 ]]
then
	echo '{"LEVEL":"ERROR","MESSAGE":"RPM Url is not valid"}';
	exit;
fi

LIST_OF_SERVICE_GROUPS=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "/opt/ericsson/enminst/bin/vcs.bsh --groups | awk '{print \\\$2}' | grep ^Grp | sort | uniq  | tr '\n' ' ' "`

if [[ ${LIST_OF_SERVICE_GROUPS_CHECK} != "" ||`echo $LIST_OF_SERVICE_GROUPS_CHECK | grep Traceback` == "" ]]
then

	echo "{\"LEVEL\":\"SUCCESS\",\"MESSAGE\":\"${LIST_OF_SERVICE_GROUPS}\"}";
	exit;

else

	echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"There was a problem retrieveing service groups\"}";
	exit;

fi



#ORIGINAL_RPM=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5  -o BatchMode=yes  root@${MSIP} "ls -l ${ENM_SERVICES_DIR}/${RPM_NAME_SPLIT}*" | grep -v cannot`


if [[ ${ORIGINAL_RPM} == "" ]]
then

	echo "{\"LEVEL\":\"SUCCESS\",\"MESSAGE\":\"${LIST_OF_SERVICE_GROUPS}\"}";

else

	echo "Located $ORIGNAL_RPM"

fi