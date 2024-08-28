#!/bin/bash

echo ""
echo "Script to take periodic jstack and top (by thread list) command printouts from VM's"
echo "(printouts are stored in /ericsson/enm/dumps/JSTACKS/)"

GAP=30;       # Default Time Interval between jstack/top snapshots
sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'



displayHelpMessage() {
        echo 
        echo "Usage: $0 {-s service_hostname | -g service_group } [ -t time_interval ] [ -n number_of_snapshots ]"
        echo 
        echo "Examples:"
        echo "    1) Take jstack & top printouts from just 1 jboss instance every 20 secs and repeat 5 times:"
        echo "    # $0 -s svc-1-mscm -t 20 -n 5"
        echo ""
        echo "    2) Take jstack & top printouts every 30s from all jboss instances running in this Service Goup:"
        echo "    # $0 -g mscm"
        echo 
        echo "Note1: time_interval default = 30 s" 
        echo "Note2: default number_of_snapshots is default" 
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
        t ) GAP=${OPTARG} ;;
        n ) REPEAT=${OPTARG} ;;
        h ) displayHelpMessage; exit 0 ;;
        * ) echo "Invalid input ${opt}; use -h for help"; exit 1 ;;
    esac
done


# Create file on SFS to be sourced on the VM in order to get the jstack/top info
JSTACK_FILE=/ericsson/enm/dumps/.take_jstack_and_thread_info_from_vm

if [ ! -f $JSTACK_FILE ]; then

	# Need to ensure that the EOF at end of here-doc is preceeded by tab rather than spaces, when using indentation
	cat > $JSTACK_FILE <<- "EOF"

        JAVA_PID_LIST=$(ps -ef | egrep HeapDumpOnOutOfMemoryError | egrep -v 'egrep|Ds=instr' | awk '{print $2}');
        DIR=/ericsson/enm/dumps/JSTACKS/$(hostname); 
        mkdir -p $DIR;
        DATE=$(date +%y%m%d.%H%M%S)
        echo "#Taking top printout";             
        top -H -n 1 -b > $DIR/top.$(hostname).$DATE; 
        for PID in $JAVA_PID_LIST; 
        do
                USER=$(ps -eo pid,user | egrep -w $PID | awk '{print $NF}')
                echo "#Taking lsof printout for java pid: $PID";   
                lsof -p $PID > $DIR/lsof.$(hostname).$PID.$DATE
                echo "#Taking jstack printout for java pid: $PID";  
                su - $USER -c "/usr/java/default/bin/jstack $PID" > $DIR/jstack.$(hostname).$PID.$DATE; 
        done
        echo "#Compressing printouts"
        gzip $DIR/lsof.$(hostname)*$DATE > /dev/null 2>&1
        gzip $DIR/jstack.$(hostname)*$DATE > /dev/null 2>&1
        gzip $DIR/top.$(hostname).$DATE > /dev/null 2>&1
	
	EOF
fi

echo ""
echo -n "# Taking jstacks and thread info for ";

if [ ! -z $SVC_GROUP ]; then
        SVC_LIST=$(egrep "\-$SVC_GROUP\s" /etc/hosts | awk '{print $2}' | sort)
        echo "$SVC_GROUP instances"; 
else
        SVC_LIST=$SVC
        echo "$SVC instance"; 
fi


# Give some dummy value to REPEAT is not specified, to allow for pseudo infinite loop
if [ "$REPEAT" == "" ]; then
        REPEAT=9999
fi


# Continue to get jstack/top printouts until user interrupts the script
for ((i=1; i<=$REPEAT; i++))
do
        # Enable infinite loop
        [[ $REPEAT -eq 9999 ]] && i=1

        # ssh to each VM in SVC_LIST and grab the jstack/top info   
        for SVC in $SVC_LIST; do 
                echo "# $i $SVC $(date)"; 
                $sshvm $SVC ". $JSTACK_FILE"; 
                if [ $? -ne 0 ]; then echo "# Problem connecting to $SVC with ssh...exiting"; exit 0; fi
        done;    

        echo "# Sleeping for ${GAP}s"; 
        echo ""
        sleep $GAP; 

done



