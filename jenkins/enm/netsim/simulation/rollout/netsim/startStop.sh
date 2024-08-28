#!/bin/sh

# Variables
DEBUG=0
RNS_LIST=""
NETSIM_DIR="/netsim/netsimdir/"
NETSIM_PIPE="/netsim/inst/netsim_pipe"
DATE=$(date +"%h_%m_%H_%M")
COMMAND_FILE="tmp_${DATE}.cmd"
ACTION=""

#############
# Functions #
#############

printUsage() {
	echo ""	
	echo "Script to stop or start nodes in LTE sims"
	echo ""	
	echo "$0 <action> [<rns>]"
	echo ""
	echo "where"
	echo ""
	echo "     <action> is either 'start' or 'stop'"
	echo "     <rns> optional parameter allowing a user to specify a specific sim."
	echo "           If not specified, the action will be performed on all sims"
	echo "           User need only supply an rns name e.g. LTE20. The script wll determine the matching sim."
	echo ""
	
	exit 1
}

checkAction() {
	if [[ $1 == "start" || $1 == "stop" ]]; then
		ACTION=$1		
	else
		printUsage
	fi
}

createCommandFile() {
	
	touch ${COMMAND_FILE}
	
	for rns in ${RNS_LIST}
	do
		sim=$(ls ${NETSIM_DIR} | grep ${rns} | grep -v zip)

		if [ $? -eq 0 ]; then
			echo ".open default" >> ${COMMAND_FILE}
			echo ".open $sim" >> ${COMMAND_FILE}
			echo ".select network" >> ${COMMAND_FILE}
			echo ".${ACTION}" >> ${COMMAND_FILE}
		else
			echo "Could not find matching sim for: $rns"
		fi
	done
}

executeCommandFile() {
	if [ ${DEBUG} -eq 0 ]; then
		cat ${COMMAND_FILE} | ${NETSIM_PIPE}
	else
		printf "\nThe following netsim pipe commands will be used:\n\n"
		cat ${COMMAND_FILE}
	fi
}

cleanUp() {
	rm ${COMMAND_FILE}
}

########
# Main #
########

ACTION=$1
checkAction ${ACTION}

if [ $# -eq 1 ]; then
	RNS_LIST=$(ls ${NETSIM_DIR} | sed -n 's/\(.*\)\.zip/\1/p')
elif [ $# -eq 2 ]; then
	RNS_LIST=$2
else
	printUsage
fi
	
createCommandFile
executeCommandFile
cleanUp

