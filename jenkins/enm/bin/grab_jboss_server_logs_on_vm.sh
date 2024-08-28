#!/bin/bash

echo ""
echo "Script to grab the Jboss server logs from a VM"
echo "(printouts are stored in /ericsson/enm/dumps/JBOSS_LOGS/)"

sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'



displayHelpMessage() {
        echo 
        echo "Usage: $0 {-s service_hostname | -g service_group } "
        echo 
        echo "Examples:"
        echo "    1) Grab Jboss server logs from just 1 jboss instance:"
        echo "    # $0 -s svc-1-mscm "
        echo ""
        echo "    2) Grab Jboss server logs from all instances running in this Service Goup:"
        echo "    # $0 -g mscm"
        echo 

        exit 0
}


# If no arguments passed to this script, then display help message, and exit
[[ $# == 0 ]] && displayHelpMessage


# Process the different options passwed to script
while getopts "s:g:t:n:h" opt; do
    case $opt in
        s ) SVC=${OPTARG} ;;
        g ) SVC_GROUP=${OPTARG} ;;
        h ) displayHelpMessage; exit 0 ;;
        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
    esac
done


# Create file on SFS to be sourced on the VM in order to grab the logs 
COMMAND_FILE=/ericsson/enm/dumps/.grab_jboss_server_logs_on_vm

if [ ! -f $COMMAND_FILE ]; then

        echo '
        DIR=/ericsson/enm/dumps/JBOSS_LOGS/$(hostname); 
        mkdir -p $DIR; 
        tar -cvf $DIR/server_logs.$(hostname).jboss.$(date +%y%m%d.%H%M%S).tar /ericsson/3pp/jboss/standalone/log/; 
        gzip $DIR/server_logs.$(hostname).jboss.*.tar &

        ' > $COMMAND_FILE

fi

echo ""
echo -n "Grab Jboss server logs for ";

if [ ! -z $SVC_GROUP ]; then
        SVC_LIST=$(egrep "\-$SVC_GROUP\s" /etc/hosts | awk '{print $2}' | sort)
        echo "$SVC_GROUP instances"; 
else
        SVC_LIST=$SVC
        echo "$SVC instance"; 
fi



# ssh to each VM in SVC_LIST and grab the Jboss logs    
for SVC in $SVC_LIST; do 
        echo $i $SVC $(date); 
        $sshvm $SVC ". $COMMAND_FILE"; 
        if [ $? -ne 0 ]; then echo "Problem connecting to $SVC with ssh...exiting"; exit 0; fi
        echo "Logs stored at: /ericsson/enm/dumps/JBOSS_LOGS/$SVC"
        echo
done;    


