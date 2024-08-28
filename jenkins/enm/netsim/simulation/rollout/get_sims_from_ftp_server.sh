#!/bin/sh

SIMPATH=$1
SIMDIR=$2
FTP_SERVER="ftp.athtem.eei.ericsson.se"

#############
# Functions #
#############

printUsage() {
	printf "\nThis script will attempt to ftp simulations from the ftp server\n"
	printf "FTP Server: ${FTP_SERVER}\n\n"
}

########
# Main #
########

printf "\nftping sims from [$FTP_SERVER] [$SIMPATH]\n\n"

cd $SIMDIR

ftp -n -i $FTP_SERVER <<END_FTP
user simguest simguest 
bin
cd $SIMPATH 
mget *.zip
bye
END_FTP

if [ "$(ls $SIMDIR | wc -l)" ]
then
    exit 0
else
	exit 1
fi
