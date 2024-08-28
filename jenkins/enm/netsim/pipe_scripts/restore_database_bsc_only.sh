#!/bin/bash
## Script to restore the NE DataBase for BSCs only
SIMLIST=`ls ~/netsimdir | grep BSC| grep -v ".zip"`
SIMS=(${SIMLIST// / })
echo  ${SIMS[@]}
for SIM in ${SIMS[@]}
do
NODE=`echo -e '.open '$SIM' \n .show simnes' | ~/inst/netsim_shell | grep -i "LTE BSC" |cut -d" " -f1`
echo $NODE
for i in $NODE
do
rm -rf bsc_name.mml
cat >> bsc_name.mml << XYZ
.open $SIM
.select $i
.stop
.restorenedatabase curr all force
.start
XYZ
/netsim/inst/netsim_shell < bsc_name.mml
done
done
