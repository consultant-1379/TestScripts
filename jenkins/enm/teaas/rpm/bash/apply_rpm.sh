#!/bin/bash


######## CONFIG ################

ENM_SERVICES_DIR="/var/www/html/ENM_services"
ENM_MODEL_DIR="/var/www/html/ENM_models"
DEPLOYMENT_ID=$1
RPM_URL=$2
JIRA_TICKET_ID=$3
install_type=$4
LIST_OF_SERVICE_GROUPS_TO_OFFLINE=$5
TIMESTAMP=$6
URL_INSTALL_RPM_SCRIPT="http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/bash/s4_install_rpm_lms.txt"

MSIP=`wget -q -O - --no-check-certificate "https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId=${DEPLOYMENT_ID}&tunnel=true" | awk -F',' '{print $1}' | awk -F':' '{print $2}' | sed -e "s/\"//g" -e "s/ //g"`
RPM_NAME=`echo ${RPM_URL} | awk -F"/" '{print $NF}'`
RPM_DIR_LMS="/var/tmp"

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

	#Download script on lms to install rpm
	`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "mkdir -p /var/tmp/s4;wget -q ${URL_INSTALL_RPM_SCRIPT} -O /var/tmp/s4/s4_install_rpm_lms.sh;touch /var/tmp/s4/s4_install_rpm_lms.sh;"`
	
	CHECK_RPM_INSTALL_SCRIPT_ON_LMS=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "ls /var/tmp/s4/s4_install_rpm_lms.sh"`	
	if [[ ${CHECK_RPM_INSTALL_SCRIPT_ON_LMS} == "/var/tmp/s4/s4_install_rpm_lms.sh" ]]
	then
		#Make a directory for the ticket_id
		`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "mkdir -p ${RPM_DIR_LMS}/${JIRA_TICKET_ID}"`;
		
		#Make a directory for the ticket_id
		ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "mkdir -p ${RPM_DIR_LMS}/${JIRA_TICKET_ID}/${NEW_RPM_DIR_NAME};"
		

		#Create a log file 
		now=`date '+%Y_%m_%d_%H:%M:%S'`
		LOG_FILE=${RPM_DIR_LMS}/${JIRA_TICKET_ID}/${now}.log
		
		#Run the script on the lms with parameters
		S4_INSTALL_SCRIPT=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "touch ${LOG_FILE};chmod 755 /var/tmp/s4/s4_install_rpm_lms.sh; /var/tmp/s4/s4_install_rpm_lms.sh ${DEPLOYMENT_ID} ${RPM_URL} ${JIRA_TICKET_ID} ${install_type} ${LIST_OF_SERVICE_GROUPS_TO_OFFLINE} ${TIMESTAMP} ${LOG_FILE} | tee ${LOG_FILE}"`
		#echo "{\"LEVEL\":\"SUCCESS\",\"MESSAGE\":\"RPM installation has been started on ${LIST_OF_SERVICE_GROUPS_TO_OFFLINE}\"}";
		exit;
		
	else
			echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"Could not install RPM - s4_install_rpm_lms.sh is missing on LMS\"}";
		
	fi

else

	echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"Cannot get a list of service groups from LMS\"}";
	exit;

fi


	
	
	#Move orignal rpm to /var/tmp
	#var RPM_TO_REPLACE=``ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "ls /
	
	#Download the RPM onto the LMS
	#`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP} "mkdir -p ${RPM_DIR_LMS}/${JIRA_TICKET_ID}/${NEW_RPM_DIR_NAME}; wget -q ${RPM_URL} -O ${RPM_DIR_LMS}/${JIRA_TICKET_ID}/${NEW_RPM_DIR_NAME}/${RPM_NAME};touch ${RPM_DIR_LMS}/${JIRA_TICKET_ID}"`
	  







