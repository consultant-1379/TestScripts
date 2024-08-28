#!/bin/bash

if [ $# -ne 1 ]
then
echo "Syntax ERROR - Must pass 1 argument i.e. node name, to the script"
echo "Eg:       ./restoredb_netsim_nodes.sh LTE01dg2ERBS00001" | sed "s/^/\t\t/g"
echo
exit 1
fi

node=$1

#echo ${node}
#netsim=`grep -rilw ${node} /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP "ieatnetsimv[0-9]{4}-[0-9][0-9]"`
#sim=`grep ${node} -riw /opt/ericsson/enmutils/etc/nodes/| grep -v failed | awk -F ", " '{print $23}'`
#for i in `/opt/ericsson/enmutils/bin/cli_app "cmedit get * CmFunction.syncStatus!=SYNCHRONIZED -t" | grep dg2|awk '{print $1}'`;
#for i in {ieatnetsimv7038-18_LTE03ERBS00001,ieatnetsimv7038-25_LTE29ERBS00016,CORE04MLTN-5-4-00114};
for i in $node;
do echo $node;
netsim=`grep -ril $i /opt/ericsson/enmutils/etc/nodes/ | grep -v failed | grep -oP "ieatnetsimv[0-9]{4}-[0-9]{2,3}"`
sim=`grep $i -ri /opt/ericsson/enmutils/etc/nodes/| grep -v failed | awk -F ", " '{print $23}' | tail -1`
echo $netsim
echo $sim
/usr/bin/ssh -o StrictHostKeyChecking=no netsim@${netsim} "echo -e "\"".stop\n.restorenedatabase curr all force\n.start"\"" | /netsim/inst/netsim_shell -sim ${sim} -ne ${i}"
done

#E.g. db stored: ["CORE04MLTN-5-4-00114 /netsim/netsimdir/MLTN5-4FPx160-04/allsaved/dbs/curr_CORE04MLTN-5-4-00114 no such file or directory"]

#Example command to restore full simulation
#echo -e ".open CORE-ST-SpitFire-17B-V3x160-01\n.selectnocallback network\n.stop -parallel\n.restorenedatabase curr all force\n.start -parallel" | /netsim/inst/netsim_shell