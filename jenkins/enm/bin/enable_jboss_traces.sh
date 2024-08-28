#!/usr/bin/env bash

VM=$1
TRACELEVEL=$2
TRACE=$3
SSHVM=/root/rvb/bin/ssh_to_vm_and_su_root.exp

if [ $# -ne 3 ]
then
echo "  Syntax ERROR  "
echo "          ./enable_jboss_traces <vm_name> <trace_level> <trace_name> "
echo "Eg:       ./enable_jboss_traces svc-1-netex TRACE com.ericsson.oss.itpf.datalayer.dps.global.connection.ConnectionProbeBean"
echo "Eg:       ./enable_jboss_traces netex DEBUG com.ericsson.oss.itpf.datalayer.dps.global.connection.ConnectionProbeBean"
echo
exit 1
fi

echo ""

for i in `grep ${VM} /etc/hosts | awk '{print $2}'`
        do
                echo -e "\e[0;32mAdding a new trace level for\e[0m" "\e[0;34m${TRACE}\e[0m" "\e[32mwith level\e[0m" "\e[0;34m${TRACELEVEL}\e[0m" "\e[0;32menabled.\e[0m"
                echo ""
                ${SSHVM} $i  "/ericsson/3pp/jboss/bin/jboss-cli.sh -c --command='/subsystem=logging/logger=${TRACE}:add(level=${TRACELEVEL})'" | sed "s/^/\t/g"

                echo -e "\e[0;32mChecking trace level for\e[0m" "\e[0;34m${TRACE}\e[0m" "\e[0;32mwith level\e[0m" "\e[0;34m${TRACELEVEL}\e[0m" "\e[0;32mis enabled.\e[0m"
                echo ""
                ${SSHVM} $i "/ericsson/3pp/jboss/bin/jboss-cli.sh -c --command='/subsystem=logging/logger=${TRACE}:read-attribute(name=level)'" | sed "s/^/\t/g"
        done

#Example command to remove trace
#sshvm svc-1-netex "/ericsson/3pp/jboss/bin/jboss-cli.sh -c --command='/subsystem=logging/logger=com.ericsson.oss.itpf.datalayer.dps.global.connection.ConnectionProbeBean:remove()'"
