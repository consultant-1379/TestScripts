#!/bin/bash

numberOfUsers=$1
everyXthHour=$2
durationOfEachAmosSession=$3

for ((i=1; i<=$numberOfUsers; i++))
do
    sitefilenum=`printf "%.3d" $i`
    let cmdfilenum=$i%4+1
    let vmnum=$i%2+1 
    echo "20 */$everyXthHour * * * /opt/ericsson/amos/bin/mobatch -g -p 1 -t 60 -i 30 -v duration=$durationOfEachAmosSession,cmdfile='/home/shared/common/amos_load/cmds_lte_amos_op_${cmdfilenum}.txt',corba_class=2 /home/shared/common/amos_load/ipdatabase_${sitefilenum} /home/shared/common/amos_load/lte_amos_for_ever_wrapper" > /ericsson/vmcrons/scp-${vmnum}-scripting/amos$i &
done
