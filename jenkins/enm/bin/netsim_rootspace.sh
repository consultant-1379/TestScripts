#!bin/bash/sh

#Script to check the netsim root space



#below script will create a list which contain all netsim vm names
sh netsim_list.sh

if [ -s /root/rvb/bin/netsim_rootspacecheck/netsim_list.txt ]

then

#iterating over a list of all netsim vms

for i in `cat /root/rvb/bin/netsim_rootspacecheck/netsim_list.txt`; do

	echo -e "Netsim VM :  $i"| sed 's/^/\t/g';
        echo "============================="|sed 's/^/\t/g';
        echo "Checking the root space used "

#logging into each netsim vms and checking root space

	 echo " "

        ssh -o StrictHostKeyChecking=no root@$i "exec df -kh /"|sed 's/^/\t/g';

#checking for stopped nodes if any

	echo " "
        echo -e "Checking for any stopped nodes:";

       # SIMS_NOT_STARTED=$(ssh -o StrictHostKeyChecking=no root@$i "echo '.show allsimnes' | /netsim/inst/netsim_shell | grep 'not started' | cut -d' ' -f1")

SIMS_NOT_STARTED=$(ssh -o StrictHostKeyChecking=no root@$i "echo '.show allsimnes' | /netsim/inst/netsim_shell | grep 'not started' ")

        if [[ ${SIMS_NOT_STARTED} == "" ]] ;
        then
                echo "INFO: All nodes are successfully started." | sed 's/^/\t\t/g'

        else
                echo -e "ERROR: The following nodes under $i are not started . Please check......." | sed 's/^/\t/g'
                echo ${SIMS_NOT_STARTED} | sed 's/^/\t\t\t/g'

        fi

	echo " "
        echo " "

 done

else
        echo "================================================="
        echo "Not able to fetch the Netsim details!..........."
        echo "================================================="
fi
