#!/bin/bash

numberOfUsers=$1
amosUsersFile=`dirname $0`/amos_users.csv

echo "USERNAME,FIRSTNAME,LASTNAME,EMAIL,ROLES" > $amosUsersFile
for ((i=1; i <= $numberOfUsers; i++))
do
    echo "amos$i,amos$i,soma$i,amos$i@ericsson.com,Amos_Operator,Network_Explorer_Operator" >> $amosUsersFile
done

/opt/ericsson/enmutils/bin/user_mgr create --file $amosUsersFile Soma1234

mkdir -p /home/shared
mkdir -p /ericsson/vmcrons
nas_mount=`df /var/ericsson/ddc_data/ | grep ddc | sed -n 's/^\(.*\)-.*/\1/gp'`
mount -t nfs $nas_mount-cron /ericsson/vmcrons
mount -t nfs $nas_mount-home /home/shared

if [ -d /home/shared/common/amos_load ]
then
    rm -rf /home/shared/common/amos_load
fi

mkdir -p /home/shared/common/amos_load
cp `dirname $0`/* /home/shared/common/amos_load

/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CppConnectivityInformation.ipAddress -t' | grep netsim | awk '{sub(/^.*_/, "", $2); {printf("%s %s secret secure_shell=0,secure_ftp=0,username=%s\n",$1,$4,$2)}}' | sed -e 's/^ //g'| sed -e 's/  */ /g' | grep -v NodeId > /home/shared/common/amos_load/ipdatabase

numberOfNodes=`wc -l /home/shared/common/amos_load/ipdatabase | awk '{print $1}'`
let numberOfNodesPerSitefile=$numberOfNodes/$numberOfUsers
split -d -a 3 -l $numberOfNodesPerSitefile /home/shared/common/amos_load/ipdatabase /home/shared/common/amos_load/ipdatabase_

let everyXthHour=$numberOfNodesPerSitefile/6+1
let durationOfEachAmosSession=$everyXthHour*60/$numberOfNodesPerSitefile

/home/shared/common/amos_load/run_amos_batch.sh $numberOfUsers $everyXthHour $durationOfEachAmosSession

umount /ericsson/vmcrons
umount /home/shared
rmdir /ericsson/vmcrons
rmdir /home/shared
