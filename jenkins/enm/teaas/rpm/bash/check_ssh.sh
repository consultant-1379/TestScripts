#!/bin/bash


######## CONFIG ################


MSIP=$1

################################

#Check ssh connection
CHECK_SSH_CONNECTION=`ssh -q -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@${MSIP}`
CHECK_SSH_CONNECTION_EXIT_CODE=`echo $?`
if [[ $CHECK_SSH_CONNECTION_EXIT_CODE != 0 ]]
then
		echo 1
		exit;
else
		echo 0
		exit;
fi

