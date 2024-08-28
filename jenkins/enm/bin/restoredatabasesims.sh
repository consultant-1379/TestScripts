#!/bin/sh
SIMLIST=''LTEG1281-limx160-60K-FDD-LTE96' 'LTEG1281-limx160-60K-FDD-LTE97' 'LTEG1281-limx160-60K-FDD-LTE98' 'LTEG1281-limx160-60K-FDD-LTE99''
for SIM in $SIMLIST

 do


        echo ".open $SIM"
        echo ".selectnocallback network"
        echo '.stop -parallel'
        echo ".restoredborfsdialog dbs .restorenedatabase resp /netsim/netsimdir/$SIM curr!!!auto"
        echo ".restorenedatabase /netsim/netsimdir/$SIM/allsaved/dbs/curr"
        echo '.start -parallel'
 done
