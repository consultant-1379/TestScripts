alias sudo='sudo '
#RVB:ALIASES
alias sshvm='/root/rvb/bin/ssh_to_vm_and_su_root.exp'
alias dumps='cd /ericsson/enm/dumps/'
alias list_unsynced='/opt/ericsson/enmutils/bin/cli_app "cmedit get * CmFunction.syncStatus!=SYNCHRONIZED -t"'
alias total_active_alarms='/opt/ericsson/enmutils/bin/cli_app "cmedit get * OpenAlarm --count" '
alias boss?='echo "/ericsson/3pp/jboss/standalone/log/" '

#Joe's funtions
grepvm() {
hosttype=$1
regex=$2
getent hosts | egrep "$hosttype" | awk '{print $2}' | while read host; do sshvm $host "boss; egrep --color '$regex' /ericsson/3pp/jboss/standalone/log/server.log"; done
}

#RVB:VAR - TERMINAL MODIFICATIONS
export HISTTIMEFORMAT="%h/%d - %H:%M:%S "

WORKLOAD_VM=ieatwlvm7011.athtem.eei.ericsson.se
alias connect_to_vm='ssh -o StrictHostKeyChecking=no $WORKLOAD_VM'

nodemappings() { CLUSTER_TYPE=$1; [[ -z $CLUSTER_TYPE ]] && { printf "Show mapping between litp node and hostname.\nUsage: $FUNCNAME cluster_type\n where node_type=all, svc, scp or db etc\n"; return; }; [[ "$CL
USTER_TYPE" == "all" ]] && CLUSTER_LIST=$(litp show -p /deployments/enm/clusters/ | egrep '_cluster' | awk -F[/_] '{print $2}') || CLUSTER_LIST=$CLUSTER_TYPE; for CLUSTER in $CLUSTER_LIST; do NODE_LIST=$(litp s
how -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/ | egrep -v ':|^/' | awk -F'/' '{print $NF}');  for NODE in $NODE_LIST; do echo $NODE: $(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes
/$NODE | egrep hostname| awk '{print $NF}'); done; done }
authenticateMe() { [[ $# -eq 2 ]] && { USER=$1; PW=$2; } || { USER="administrator"; PW="TestPassw0rd"; echo "Using default username and password"; echo "Override with: \"$FUNCNAME user pw\""; }; DATE=$(date +%y
%m%d.%H%M%S); DAY=$(date +%y%m%d); COOKIE_NAME=myRvbCookie; for OLD_COOKIE in $(ls /tmp | egrep $COOKIE_NAME| egrep -v $DAY); do rm -f /tmp/$OLD_COOKIE; done; COOKIE_FILE=/tmp/$COOKIE_NAME.$DATE; HAPROXY=$(egre
p haproxy /etc/hosts | awk '{print $3}'); SSO_URL="http://sso-instance-1.${HAPROXY}:8080/heimdallr/UI/Login?IDToken1=${USER}&IDToken2=${PW}"; CURL_COMMAND="curl -c $COOKIE_FILE -X POST $SSO_URL"; echo "Authenti
cating with this command: $CURL_COMMAND"; echo -n "Executing ... "; $CURL_COMMAND; echo "done"; }
