#!/bin/bash

### Physical environment only
### This script is to collect the logs
### for the corresponding ENM instances
### which are passed in the arguments
### "<script> <log directory name to store> <applications name(s)>"
### "Example: sh enmLogCollection.sh TORF-xxxxxx  mspm,medrouter,pmserv,cmserv"

DUMPS_FS_LIMIT=90

function help()
{
   echo "Run the script with following arguments"
   echo "<script> <log directory name to store> <applications name(s)>"
   echo "Example: sh enmLogCollection.sh TORF-xxxxxx  mspm,medrouter,pmserv,cmserv"
   echo -e "The directory will be created in /ericsson/enm/dumps\n"
}

function validateInstanceName()
{
   instances=$1

   for inst in $(echo ${instances} | tr "," "\n")
   do

      if [[ ${inst} =~ "neo" ]];
      then
         GREP=$(awk '{print $2}' /etc/hosts | egrep "\b${inst}.*\b")
      else
         GREP=$(awk '{print $2}' /etc/hosts | egrep "\b${inst}\b")
      fi

      if [ $? -ne 0 ]
      then
         echo -e "Check the instance name of 'inst' and correct it\n"
         help
         exit 1
      fi
   done
}

if [ "$#" -ne 2 ];
then
   help
   exit 1
fi

if [ $(df -Ph /ericsson/enm/dumps/ | grep -v Filesystem | awk '{print $5}' | cut -d'%' -f1) -ge ${DUMPS_FS_LIMIT} ];
then
   echo -e "/ericsson/enm/dumps FS is above ${DUMPS_FS_LIMIT}%. So logs will not be collected. Reduce the FileSystem size and retry"
   echo -e "$(df -Ph /ericsson/enm/dumps/)"
   exit 1
fi

validateInstanceName $2

dir=$1

instance=$(echo $2 | sed -e 's/^/\\b/' -e 's/,/\\b|\\b/g' -e 's/$/\\b/')

DIR="/ericsson/enm/dumps/${dir}/$(date +'%F')_$(date +'%H%M%S')";
mkdir -p ${DIR} && chmod 777 ${DIR};

JBOSSLOG="/ericsson/3pp/jboss/standalone/log/server.log*"
MSGLOG="/var/log/messages"

for ip in $(awk '{print $2}' /etc/hosts | egrep "${instance}");
do
   echo "============ ${ip} ============";

   if [[ $ip =~ "winfiol" ]]; then
      WINFIOLLOGS="/ericsson/log/winfiol-server/w*.log*"
      LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG} ${WINFIOLLOGS}"
   elif [[ $ip =~ "smrsserv" ]]; then
      SECURELOGS="/var/log/secure"
      LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG} ${SECURELOGS}"
   else
      LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG}"
   fi   

   ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=150 -i /root/.ssh/vm_private_key cloud-user@${ip} "sudo tar -zcvf ${DIR}/${ip}.serverlog.tgz -P ${LOGSTOCOLLECT}";
done

echo -e "\nLogs of \"$2\" instance(s) copied to \"${DIR}\" in LMS \"$(hostname)\""
echo -e "size of logs collected $(echo $(du -sh ${DIR}) | awk '{print $1}')\n"
