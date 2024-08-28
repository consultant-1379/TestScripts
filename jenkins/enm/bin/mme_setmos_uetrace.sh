#!/bin/bash
echo ".show simnes" | ./netsim_pipe -sim $1 | cut -d ' ' -f 1 | tail -n+3 | sed '$d' > ./logfiles/update_mo.log
while read p; do
./netsim_pipe -sim $1 -ne $p <<EOF
echo $p
    .start
    setmoattribute:mo="ManagedElement=$p,SgsnMme=1,PLMN=1",attributes="mobileNetworkCode=01";
    setmoattribute:mo="ManagedElement=$p,SgsnMme=1,PLMN=1",attributes="mobileCountryCode=272";
    .stop
EOF
done<./logfiles/update_mo.log
