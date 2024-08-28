#!/bin/bash

BASHRC_FILE="$HOME/.bashrc"

copy_bashrc_file() {
	echo "$FUNCNAME - $(date)"
	BASHRC_FILE_NEW=$BASHRC_FILE.new
	cp $BASHRC_FILE $BASHRC_FILE.orig
	cp $BASHRC_FILE $BASHRC_FILE_NEW
}

add_workload_server_entries() {
        echo "$FUNCNAME - $(date)"

        echo "#Remove existing entries"
	perl -p -i -e 's/.*\#RVB:WORKLOAD.*|.*WORKLOAD.*|.*BladeRunners.*//' $1  

	echo "#Add new entries"
	DEPLOYMENT_ID=$(cat /var/ericsson/ddc_data/config/ddp.txt | perl -pe 's/lmi_ENM(.*)/$1/' | perl -pe 's/ //g')
	if [ -z $DEPLOYMENT_ID ]; then
		echo "DDP not configured on machine. Needs to be populated so that WORKLOAD_SERVER can be worked out"
	else
		WORKLOAD_SERVER=$(egrep WORKLOAD /root/rvb/deployment_conf/5$DEPLOYMENT_ID.conf | awk -F'=' '{print $2}')
		[[ -z $WORKLOAD_SERVER ]] && { echo "WORKLOAD_SERVER is not configured in deployment conf file"; } || { echo >> $1; echo "#RVB:WORKLOAD SERVER" >> $1; echo WORKLOAD_VM=$WORKLOAD_SERVER >> $1; }
	fi

}


add_aliases() {
	echo "$FUNCNAME - $(date)"

	echo "#Remove existing entries"
	perl -p -i -e 's/.*\#RVB:ALIASES.*|.*alias (sshvm=.*|dumps=.*|list_unsynced=.*|total_active_alarms=.*|boss\?=.*|connect_to_vm.*)//' $1

	echo "#Add new entries"
    cat >> $1 <<- "EOF"
		 
		#RVB:ALIASES
		alias sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'
		alias dumps='cd /ericsson/enm/dumps/'
		alias list_unsynced='/opt/ericsson/enmutils/bin/cli_app "cmedit get * CmFunction.syncStatus!=SYNCHRONIZED -t"'
		alias total_active_alarms='/opt/ericsson/enmutils/bin/cli_app "cmedit get * OpenAlarm --count" '
		alias boss?='echo "/ericsson/3pp/jboss/standalone/log/" '
		alias connect_to_vm='ssh -o StrictHostKeyChecking=no $WORKLOAD_VM'
		 
	EOF
}


add_extra_variables() {
    echo "$FUNCNAME - $(date)"

    echo "#Remove existing entries"
    perl -p -i -e 's/.*\#RVB:VAR.*|.*TERMINAL MOD.*|.*Changes prompt.*|.*Updates PROMPT_COMMAND.*|.*for lazy invocation.*|.*HISTTIMEFORMAT=.*|.*PS1=.*|.*PROMPT_COMMAND=.*|.*PATH=.*rvb.*//' $1

    echo "#Add new entries"
    cat >> $1 <<- "EOF"
		  
		#RVB:VAR - TERMINAL MODIFICATIONS
		export HISTTIMEFORMAT="%h/%d - %H:%M:%S "
		  	
		#RVB:VAR - Changes prompt to include timestamp: e.g: [14:49:06 root@ieatlms5218:~ ]#
		PS1="[\t \u@\h:\W ]# "
		  	
		#RVB:VAR - Updates PROMPT_COMMAND with history -a so that all commands ran as root update ~/.bash_history file
		PROMPT_COMMAND='history -a'
		 	
		#RVB:VAR - Modifies $PATH to include bin directories from enminst,enmutils and root/rvb for lazy invocation
		PATH=${PATH}:/opt/ericsson/enmutils/bin:/opt/ericsson/enminst/bin:/root/rvb/bin
		 

	EOF
}


add_shell_functions() {
    echo "$FUNCNAME - $(date)"

    echo "#Remove existing entries"
    perl -p -i -e 's/.*\#RVB:SHELL_FUN.*|.*nodemappings\(\).*|.*authenticateMe\(\).*//' $1

    echo "#Add new entries"
    cat >> $1 <<- "EOF"
		#RVB:SHELL_FUNCTIONS:Add some shell functions for some long-winded but valuable commands
		nodemappings() { CLUSTER_TYPE=$1; [[ -z $CLUSTER_TYPE ]] && { printf "Show mapping between litp node and hostname.\nUsage: $FUNCNAME cluster_type\n where node_type=all, svc, scp or db etc\n"; return; }; [[ "$CLUSTER_TYPE" == "all" ]] && CLUSTER_LIST=$(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}') || CLUSTER_LIST=$CLUSTER_TYPE; for CLUSTER in $CLUSTER_LIST; do NODE_LIST=$(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/ | egrep -v ':|^/' | awk -F'/' '{print $NF}');  for NODE in $NODE_LIST; do echo $NODE: $(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/$NODE | egrep hostname| awk '{print $NF}'); done; done }
		
		authenticateMe() { [[ $# -eq 2 ]] && { USER=$1; PW=$2; } || { USER="administrator"; PW="TestPassw0rd"; echo "Using default username and password"; echo "Override with: \"$FUNCNAME user pw\""; }; DATE=$(date +%y%m%d.%H%M%S); DAY=$(date +%y%m%d); COOKIE_NAME=myRvbCookie; for OLD_COOKIE in $(ls /tmp | egrep $COOKIE_NAME| egrep -v $DAY); do rm -f /tmp/$OLD_COOKIE; done; COOKIE_FILE=/tmp/$COOKIE_NAME.$DATE; HAPROXY=$(egrep haproxy /etc/hosts | awk '{print $3}'); SSO_URL="http://sso-instance-1.${HAPROXY}:8080/heimdallr/UI/Login?IDToken1=${USER}&IDToken2=${PW}"; CURL_COMMAND="curl -c $COOKIE_FILE -X POST $SSO_URL"; echo "Authenticating with this command: $CURL_COMMAND"; echo -n "Executing ... "; $CURL_COMMAND; echo "done"; }

	EOF
}


remove_empty_lines() {
    echo "$FUNCNAME - $(date)"
        
    perl -p -i -e 's/^\s*$^\s*$//g' $1
    perl -p -i -e 's/^\#/\n\#/' $1

}


update_bashrc_variables() {
	echo "$FUNCNAME - $(date)"

	[[ -z $1 ]] && { echo "No input file specified"; exit 0; }

	add_workload_server_entries $1
	add_aliases $1
	add_extra_variables $1
	add_shell_functions $1	
	remove_empty_lines $1
}

copy_bashrc_file
update_bashrc_variables $BASHRC_FILE.new
/bin/mv $BASHRC_FILE.new $BASHRC_FILE

