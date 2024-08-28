#!/bin/sh

NETSIM_DIR="/netsim/netsimdir/"
DATE=$(date +"%h_%m_%H_%M")
COMMAND_FILE="tmp_${DATE}.cmd"
NETSIM_PIPE="/netsim/inst/netsim_pipe"

#############
# Functions #
#############

#
# $1 - simulations
uncompressSimulations() {
	for sim in "$@"
	do
		sim=`basename $sim`
	    echo ".uncompressandopen ${sim} force" >> $COMMAND_FILE
	done
	cat $COMMAND_FILE | $NETSIM_PIPE
	rm -f $COMMAND_FILE
}

########
# Main #
########

SIM_LIST=$(ls ${NETSIM_DIR}*.zip)

printf "\nWill attempt to find and uncompress the following simulations:\n\n"
printf "${SIM_LIST}\n\n"

uncompressSimulations ${SIM_LIST}
