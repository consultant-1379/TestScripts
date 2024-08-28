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
saveandcompressSimulations() {
	for sim in "$@"
	do
		sim=`basename $sim`
	    echo ".open ${sim}" >> $COMMAND_FILE
	    echo ".saveandcompress force nopmdata" >> $COMMAND_FILE
	done
	cat $COMMAND_FILE | $NETSIM_PIPE
	rm -f $COMMAND_FILE
}

########
# Main #
########

SIM_LIST=$(ls ${NETSIM_DIR} | sed -n 's/\(.*\)\.zip/\1/p')

printf "\nWill attempt to find and saveandcompress the following simulations:\n\n"
printf "${SIM_LIST}\n\n"

saveandcompressSimulations ${SIM_LIST}
