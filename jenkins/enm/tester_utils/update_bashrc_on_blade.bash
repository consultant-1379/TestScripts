#!/bin/bash
BASENAME=`dirname $0`

update_root_bashrc_file_on_blade(){

    #TODO Put these echo commands into variables for neatness
    #History Timestamps
    ${BASENAME}/../bin/ssh_to_vm_and_su_root.exp $1 "echo 'export HISTTIMEFORMAT=\"%h/%d - %H:%M:%S \"' >> ~/.bashrc"
    #Update terminal prompt with timestamp
    ${BASENAME}/../bin/ssh_to_vm_and_su_root.exp $1 "echo 'PS1=\"[\t \u@\h:\W ]# \"'>> ~/.bashrc"
    #Every command goes to history logfile
    ${BASENAME}/../bin/ssh_to_vm_and_su_root.exp $1 "echo \"PROMPT_COMMAND='history -a'\" >> ~/.bashrc"

}


update_nodes()
{
	CLUSTERS=$(litp show -p /deployments/enm/clusters | egrep '/' | egrep -v deployments | cut -f2 -d'/' | cut -f1 -d'_')
	for CLUSTER in $CLUSTERS 
	do
		echo "# Cluster $CLUSTER found"
		NODES=$(litp show -p /deployments/enm/clusters/${CLUSTER}_cluster/nodes/ | egrep '/' | egrep -v deployments | cut -f2 -d'/')
		for NODE in $NODES
		do
			echo "# Updating .bashrc on node $NODE"
			update_root_bashrc_file_on_blade ${NODE}
		done
	done
}

update_nodes
